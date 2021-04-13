import { LightningElement, track, api } from 'lwc';
import getRecords from '@salesforce/apex/SimpleSimulatorController.getRecords';
import translateIds from '@salesforce/apex/SimpleSimulatorController.translateIds';
import simulate from '@salesforce/apex/SimpleSimulatorController.simulate';
import getConfiguration from '@salesforce/apex/SimpleSimulatorController.getConfiguration';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class CcSimpleSimulator extends LightningElement {

  @track member = {
    id: ''
  };
  @track hasMember = false;
  @track hasRecords = false;
  @track hasSelectedRecords = false;
  @track hasOutput = false;
  @track hasSummary = false;
  @track objectValue;
  @track output = '';
  @track filters = '';

  @track relatedRecords = [];
  @track relatedColumns = [];
  @track outputColumns = [];
  @track selectedIds;

  @track showSelectRecordsButton = false;
  @track showSimulateButton = false;

  @track currencySummary;

  @track isTableOutput = false;
  @track isSummaryOutput = false;

  @track rows;

  @track showOutput = false;

  config = {};

  @api objectName;

  connectedCallback() {
    console.log(`objectName: ${this.objectName}`);
  }

  @api
  handleMemberChange(payload) {
    if (this.member.id !== payload.member.Id) {
      this.member = payload.member;
      this.member.id = this.member.Id;
      this.getRelatedRecords();
      this.getFieloConfiguration();
    }
  }

  getRelatedRecords(){
    getRecords({
      memberId: this.member.Id,
      objectName: this.objectName
    })
    .then(result => {
      this.relatedRecords = [];
      this.relatedColumns = [];

      result &&
      result.records &&
      result.records.length &&
      result.records.forEach(function(record) {
        this.relatedRecords.push(record);
      }.bind(this))

      result &&
      result.columns &&
      result.columns.length &&
      result.columns.forEach(function(col) {
          this.relatedColumns.push(col);
      }.bind(this))

      this.hasRecords = this.relatedRecords && this.relatedRecords.length;
      this.showSimulateButton = this.hasRecords;
    })
    .catch(error => {
      console.error(error)
    })
  }

  handleSelectedRecord(event){
    this.selectedIds = event.detail.selectedRows;

    this.selectedIds.forEach(function(row) {
      row.sobjectType = this.objectValue;
    }.bind(this));

    this.hasSelectedRecords = this.selectedIds && this.selectedIds.length;
  }

  handleSimulate() {
    simulate({
      memberId: this.member.Id,
      records: this.selectedIds
    })
    .then(output => {
      var idsToTranslate = [];
      var outputObj = JSON.parse(output);

      Object.keys(outputObj).forEach(currencyId => {
        idsToTranslate.push(currencyId);
        Object.keys(outputObj[currencyId].records).forEach(recordId => {
          idsToTranslate.push(recordId);
          Object.keys(outputObj[currencyId].records[recordId].incentives).forEach(incentiveId => {
            idsToTranslate.push(incentiveId);
          })
        })
      })

      var outputStr = output;

      translateIds({idsToTranslate: idsToTranslate})
      .then(translationMap => {
        Object.keys(translationMap).forEach(fObjectId => {
          outputStr = outputStr.replaceAll(fObjectId, translationMap[fObjectId]);
        });
        this.output = outputStr;
        this.showOutput = true;
        this.jsonToTable(JSON.parse(this.output));
      })
      .catch(error => {
        this.handleError(console.error());
      })
    })
    .catch(error => {
      this.handleError(console.error());
    })
  }

  getFieloConfiguration() {
    getConfiguration({
      memberId: this.member.Id
    })
    .then(result => {
      this.config = result;
      console.info(JSON.stringify(this.config, null, 2));
      this.outputColumns = [...this.config.columns];
    })
    .catch(error => {
      this.handleError(error);
    });
  }

  handleError(error) {
    console.error(error);
    const errorEvent = new ShowToastEvent({
        title: 'Error',
        message: error && error.body && error.body.message || JSON.stringify(error),
        variant: 'error',
        mode: 'dismissable'
      });
      this.dispatchEvent(errorEvent);
  }

  jsonToTable(result) {
    this.rows = [];
    this.summaryMap = {};
    this.currencySummary = [];
    Object.keys(result).forEach(curr => {
      let records = result[curr].records;
      this.currencySummary.push({
        name: curr,
        amount: result[curr].amount,
        maximum: result[curr].maximum
      });
      Object.keys(records).forEach(record => {
        let incentives = records[record].incentives;
        Object.keys(incentives).forEach(inc => {
          let rewardings = incentives[inc].rewardings;
          rewardings.forEach(rew => {
            // Format the way we want:
            let row = {
              incentive: inc,
              status: rew.eligible ? 'Eligible' : 'Potential',
              record: record
            };
            row[curr] = rew.eligible ? incentives[inc].amount : incentives[inc].potentialAmount;
            console.log(
              JSON.stringify(row, null, 2)
            );
            this.rows.push(row);

            if (Boolean(this.summaryMap[row.incentive])) {
              if (!Boolean(this.summaryMap[row.incentive]._children))
                this.summaryMap[row.incentive]._children = [];
              this.summaryMap[row.incentive]._children.push(Object.assign({},row));
            } else {
              this.summaryMap[row.incentive] = Object.assign({},row);
            }
          });
        });
      });
    });

    this.hasSummary = Boolean(this.currencySummary && this.currencySummary.length);
    this.hasOutput = Boolean(this.rows && this.rows.length);

    if (this.hasOutput) this._selectedStep = 'output';

    var records = this.template.querySelector(".fielo-records-to-simulate");
    if (records) {
      records.classList.add('slds-hide');
    }
    var output = this.template.querySelector(".fielo-simulation-result");
    if (output) {
      output.classList.remove('slds-hide');
    }

    this.showSimulateButton = false;
    this.showSelectRecordsButton = true;
    this.toggleTable();
  }

  handleSelectRecords() {
    var records = this.template.querySelector(".fielo-records-to-simulate");
    if (records) {
      records.classList.remove('slds-hide');
    }
    var output = this.template.querySelector(".fielo-simulation-result");
    if (output) {
      output.classList.add('slds-hide');
    }
    this.showSelectRecordsButton = false;
    this.showSimulateButton = true;
  }

  handleSummaryClick() {
    this.isTableOutput = false;
    this.isSummaryOutput = true;
  }

  handleTableClick() {
    this.isTableOutput = true;
    this.isSummaryOutput = false;
  }

  outputTableElement;
  outputSummaryElement;

  initOutputs() {
    if (!Boolean(this.outputTableElement))
      this.outputTableElement = this.template.querySelector(".fielo-output-as-table");

    if (!Boolean(this.outputSummaryElement))
      this.outputSummaryElement = this.template.querySelector(".fielo-output-as-summary");
  }

  toggleTable() {
    this.initOutputs();
    this.outputTableElement.classList.remove('slds-hide');
    this.outputSummaryElement.classList.add('slds-hide');
  }

  toggleSummary() {
    this.initOutputs();
    this.outputTableElement.classList.add('slds-hide');
    this.outputSummaryElement.classList.remove('slds-hide');
  }
}