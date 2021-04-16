import { LightningElement, track, api } from 'lwc';
import getRecords from '@salesforce/apex/SimpleSimulatorController.getRecords';
import translateIds from '@salesforce/apex/SimpleSimulatorController.translateIds';
import simulate from '@salesforce/apex/SimpleSimulatorController.simulate';
import getConfiguration from '@salesforce/apex/SimpleSimulatorController.getConfiguration';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { loadStyle } from "lightning/platformResourceLoader";
import pipCss from '@salesforce/resourceUrl/pipCss';

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
  @track outputTableColumns = [];
  @track outputSummaryColumns = [];
  @track selectedIds;

  @track currencySummary;

  @track currencySummaryItemSize;

  @track isTableOutput = false;
  @track isSummaryOutput = false;

  @track rows;
  @track summaryRows;
  @track expandedRows;

  @track showSpinner = false;

  @track showOutput = false;

  @track filterLabels = {
    from: "From",
    to: "To"
  };

  @track label = {
    selectRecords: 'Select records'
  };

  config = {};
  filter = {};

  @api objectName;
  @api dateField = 'CreatedDate';

  connectedCallback() {
    console.log(`objectName: ${this.objectName}`);
    console.log(`dateField: ${this.dateField}`);
    this.showSpinner = true;

    loadStyle(this, pipCss).catch((error) => {
      console.warn(error);
    });
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
      objectName: this.objectName,
      jsonFilter: this.filters
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
      this.showSpinner = false;
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
    this.toggleSimulateButton(this.hasSelectedRecords);
  }

  handleSimulate() {
    this.showSpinner = true;
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
        console.log(this.output);
        this.showOutput = true;
        this.jsonToTable(JSON.parse(this.output));
        this.showSpinner = false;
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
      memberId: this.member.Id,
      objectName: this.objectName,
      dateField: this.dateField
    })
    .then(result => {
      this.config = result;
      console.info(JSON.stringify(this.config, null, 2));
      this.outputTableColumns = [...this.config.columns];
      let colRecord = this.config.columns.filter(function (col){return col.fieldName === 'record'})[0];
      this.outputSummaryColumns = [...this.config.columns.filter(function (col){return col.fieldName !== 'record'})];
      let incentiveIndex = this.outputSummaryColumns.map(function(col) {return col.fieldName; }).indexOf('incentive');
      this.outputSummaryColumns[incentiveIndex].label += ` / ${colRecord.label}`;

      if (this.config.dateField) {
        this.filterLabels.from = `${this.config.dateField.label} ${this.filterLabels.from}`;
        this.filterLabels.to = `${this.config.dateField.label} ${this.filterLabels.to}`;
      }
      if (this.config.objectInfo) {
        this.label.selectRecords = `Select ${this.config.objectInfo.labelPlural.toLowerCase()}`;
      }
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
    this.showSpinner = false;
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
        maximum: result[curr].maximum,
        remaining: result[curr].maximum-result[curr].amount,
        percent: (result[curr].amount/result[curr].maximum)*100
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
            newRow.id = ++summaryNum;
            newRow.incentive = record;
            newRow._children = [];
            Boolean(incentives[inc].segments && incentives[inc].segments.length) && incentives[inc].segments.forEach(segment => {
              Boolean(segment.criteria && segment.criteria.length) && segment.criteria.forEach(criterion => {
                newRow._children.push({
                  id: ++summaryNum,
                  eligibility: criterion.nameCriterion,
                  eligibleIcon: criterion.applyCriterion ? 'utility:success' : 'utility:ban'
                })
              });
            });
            Boolean(rew.criteria && rew.criteria.length) && rew.criteria.forEach(criterion => {
              newRow._children.push({
                id: ++summaryNum,
                eligibility: criterion.nameCriterion,
                eligibleIcon: criterion.applyCriterion ? 'utility:success' : 'utility:ban'
              })
            })
            this.summaryMap[row.incentive]._children.push(newRow);
            this.summaryMap[row.incentive][curr] += row[curr];
          });
        });
      });
    });
    this.summaryRows = Object.values(this.summaryMap);

    this.currencySummaryItemSize = Boolean(this.summaryRows && this.summaryRows.length) && 12 / this.summaryRows.length || 1;

    this.hasSummary = Boolean(this.currencySummary && this.currencySummary.length);
    this.hasOutput = Boolean(this.rows && this.rows.length);
    this.toggleUexSwitch(this.hasOutput);

    var records = this.template.querySelector(".fielo-records-to-simulate");
    if (records) {
      records.classList.add('slds-hide');
    }
    var output = this.template.querySelector(".fielo-simulation-result");
    if (output) {
      output.classList.remove('slds-hide');
    }

    this.toggleSimulateButton(false);
    this.toggleRecordSelectionButton(true);

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

    this.toggleRecordSelectionButton(false);
    this.toggleSimulateButton(true);
  }

  handleSummaryClick() {
    this.isTableOutput = false;
    this.isSummaryOutput = true;
  }

  handleTableClick() {
    this.isTableOutput = true;
    this.isSummaryOutput = false;
  }

  simulateBtn;
  recordSelectBtn;
  uexButtonsContainer;
  outcomeSummaryElement;

  initElements() {
    if (!Boolean(this.simulateBtn))
      this.simulateBtn = this.template.querySelector(".fielo-simulate-button");

    if (!Boolean(this.recordSelectBtn))
      this.recordSelectBtn = this.template.querySelector(".fielo-select-records-button");

    if (!Boolean(this.uexButtonsContainer))
      this.uexButtonsContainer = this.template.querySelector(".fielo-output-uex-switch");

    if (!Boolean(this.outcomeSummaryElement))
      this.outcomeSummaryElement = this.template.querySelector(".fielo-output-summary");
  }

  toggleSimulateButton(enable) {
    this.initElements();
    if(enable) {
      this.simulateBtn.classList.remove('slds-hide');
      this.outcomeSummaryElement.classList.add('slds-hide')
    } else {
      this.simulateBtn.classList.add('slds-hide');
      Boolean(this.outcomeSummaryElement) && this.outcomeSummaryElement.classList.remove('slds-hide')
    }
  }

  toggleRecordSelectionButton(enable) {
    this.initElements();
    if(enable) {
      this.recordSelectBtn.classList.remove('slds-hide');
    } else {
      this.recordSelectBtn.classList.add('slds-hide');
    }
  }

  toggleUexSwitch(enable) {
    this.initElements();
    if(enable) {
      this.uexButtonsContainer.classList.remove('slds-hide');
    } else {
      this.uexButtonsContainer.classList.add('slds-hide');
    }
  }

  initFilter() {
    if (!Boolean(this.filterFromElement))
      this.filterFromElement = this.template.querySelector(".fielo-filter__from");

    if (!Boolean(this.filterToElement))
      this.filterToElement = this.template.querySelector(".fielo-filter__to");
  }

  filterFromElement;
  filterToElement;

  handleFilter() {
    this.initFilter();

    let dateFilterStr = this.filterFromElement &&
      this.filterFromElement.value &&
      `FROM:${this.filterFromElement.value}` || '';

    dateFilterStr += this.filterToElement &&
      this.filterToElement.value &&
      `TO:${this.filterToElement.value}`;

    if (dateFilterStr) {
      let filter = {};
      filter[this.dateField] = dateFilterStr;
      this.filters = JSON.stringify(filter);
    }

    console.log(this.filters);

    this.getRelatedRecords();
  }
}