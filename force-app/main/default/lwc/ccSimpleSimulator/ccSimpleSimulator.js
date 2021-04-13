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
  @track summaryRows;
  @track expandedRows;

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
        message: JSON.stringify(error),
        variant: 'error',
        mode: 'dismissable'
      });
      this.dispatchEvent(errorEvent);
  }

  jsonToTable(result) {
    this.rows = [];
    this.expandedRows = [];
    this.summaryMap = {};
    this.currencySummary = [];
    var num = 0;
    var summaryNum = 0;
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
              id: ++num,
              incentive: inc,
              status: rew.eligible ? 'Eligible' : 'Potential',
              record: record
            };
            row[curr] = rew.eligible ? incentives[inc].amount : incentives[inc].potentialAmount;
            console.log(
              JSON.stringify(row, null, 2)
            );
            this.rows.push(row);

            if (!Boolean(this.summaryMap[row.incentive])) {
              this.summaryMap[row.incentive] = {
                incentive: inc,
                id: ++summaryNum,
              };
              this.expandedRows.push(this.summaryMap[row.incentive].id);
              this.summaryMap[row.incentive]._children = [];
              if (!this.summaryMap[row.incentive][curr])
                this.summaryMap[row.incentive][curr] = 0;
            }
            let newRow = Object.assign({},row);
            delete newRow.incentive;
            newRow.id = ++summaryNum;
            this.summaryMap[row.incentive]._children.push(newRow);
            this.summaryMap[row.incentive][curr] += row[curr];
          });
        });
      });
    });
    this.summaryRows = Object.values(this.summaryMap);
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

    this.handleSummaryClick();
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
}