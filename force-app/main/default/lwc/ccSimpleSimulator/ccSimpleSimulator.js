import { LightningElement, track, api } from 'lwc';
import getRecords from '@salesforce/apex/SimpleSimulatorController.getRecords';
import getRecord from '@salesforce/apex/SimpleSimulatorController.getRecord';
import translateIds from '@salesforce/apex/SimpleSimulatorController.translateIds';
import simulate from '@salesforce/apex/SimpleSimulatorController.simulate';
import getConfiguration from '@salesforce/apex/SimpleSimulatorController.getConfiguration';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { loadStyle } from "lightning/platformResourceLoader";
import pipCss from '@salesforce/resourceUrl/pipCss';

const recordsPerPage = 10;

export default class CcSimpleSimulator extends LightningElement {

  @track member = {
    id: ''
  };
  @track memberId;
  @track hasMember = false;
  @track hasRecords = false;
  @track hasSelectedRecords = false;
  @track hasOutput = false;
  @track hasSummary = false;
  @track output = '';
  @track filters = '';

  @track relatedRecords = [];
  @track relatedColumns = [];
  @track outputTableColumns = [];
  @track outputSummaryColumns = [];
  @track selectedRowsIds;

  @track currencySummary;

  currencyInfo;

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
    selectRecords: 'Select records',
    selectTheRecords: 'Select the records you want to simulate'
  };

  config = {};
  filter = {};

  @api objectName;
  @api dateField = 'CreatedDate';
  @api additionalFilter;

  connectedCallback() {
    console.info(`objectName: ${this.objectName}`);
    console.info(`dateField: ${this.dateField}`);
    this.showSpinner = true;

    document.addEventListener('mxmemberselector__memberselected', this.handleMemberSelected.bind(this));

    if (!this.memberSelected) {
      document.dispatchEvent(new CustomEvent('mxmemberselector__fireevents'));
    }

    loadStyle(this, pipCss).catch((error) => {
      console.warn(error);
    });
  }

  handleMemberSelected(event) {
    if (event.detail !== this.memberId) {
      this.memberId = event.detail;
      this.updateMember();
    }
  }

  async updateMember() {
    try {
      this.member = await getRecord({recordId:this.memberId});
      this.member.id = this.member.Id;
      this.getRelatedRecords();
      this.getFieloConfiguration();
    } catch (error) {
      console.error(error);
    }
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
    this.showSpinner = true;

    this.assembleFilter();

    getRecords({
      memberId: this.member.Id,
      objectName: this.objectName,
      jsonFilter: this.filters,
      recordsPerPage: recordsPerPage + 1,
      offset: this.offset
    })
    .then(result => {
      this.relatedRecords = [];
      this.relatedColumns = [];
      this.recordsIds = [];

      // Set previous status
      if (this.offset) {
        this.disablePrevious = false;
      } else {
        this.disablePrevious = true;
      }

      this.disableNext = true;

      result &&
      result.records &&
      result.records.length &&
      result.records.forEach((record, index) => {
        if ( index === recordsPerPage  ) {
          this.disableNext = false;
        } else {
          this.relatedRecords.push(record);
          this.recordsIds.push(record.Id);
        }
      });

      result &&
      result.columns &&
      result.columns.length &&
      result.columns.forEach(function(col) {
          this.relatedColumns.push(col);
      }.bind(this))

      this.hasRecords = this.relatedRecords && this.relatedRecords.length;

      this.initTable();
      if (this.table) {
        this.table.selectedRows = this.selectedRowsIds;
      }

      this.showSpinner = false;
    })
    .catch(error => {
      this.handleError(error);
    })
  }

  handleSimulate() {
    this.showSpinner = true;

    this.selectedRowsDataList.forEach(row => {
      row.sobjectType = this.objectName;
    });

    simulate({
      memberId: this.member.Id,
      records: this.selectedRowsDataList
    })
    .then(output => {
      var idsToTranslate = [];
      if (output && output.indexOf('{') != -1) {
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
          this.handleError(error);
        })
      }
    })
    .catch(error => {
      this.handleError(error);
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
      this.outputSummaryColumns[incentiveIndex].label += ` > ${colRecord.label}`;

      if (this.config?.currenciesMap && Object.keys(this.config.currenciesMap).length) {
        this.currencyInfo = Object.keys(this.config.currenciesMap).reduce((map, currId) => {
          if (this.config.currenciesMap?.[currId]?.Name) {
            map[this.config.currenciesMap[currId].Name] = this.config.currenciesMap[currId];
          }
          return map;
        }, {});
      }

      if (this.config.dateField) {
        this.filterLabels.from = `${this.config.dateField.label} ${this.filterLabels.from}`;
        this.filterLabels.to = `${this.config.dateField.label} ${this.filterLabels.to}`;
      }
      if (this.config.objectInfo) {
        this.label.selectRecords = `Select ${this.config.objectInfo.labelPlural.toLowerCase()}`;
        this.label.selectTheRecords = `Select the ${this.config.objectInfo.labelPlural.toLowerCase()} you want to simulate`;
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
      message: error &&
        error.body &&
        error.body.message ||
        (error && error.name && error.name+':') +
        (error && error.message && error.message),
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
        symbol: this.currencyInfo?.[curr]?.FieloPLT__Symbol__c,
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
            newRow.incentiveEligibleIcon = newRow.status === 'Eligible' ? 'utility:success' : 'utility:ban';
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

    this.currencySummaryItemSize = Boolean(this.currencySummary && this.currencySummary.length) && 12 / this.currencySummary.length || 1;

    console.log(`currencySummaryItemSize: ${this.currencySummaryItemSize}`);
    console.log(`this.summaryRows: ${JSON.stringify(this.summaryRows, null, 2)}`);

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

  initTable(){
    if (!Boolean(this.table))
      this.table = this.template.querySelector(".fielo-records-table");
  }

  toggleSimulateButton(enable) {
    this.initElements();
    if(enable) {
      this.simulateBtn && this.simulateBtn.classList.remove('slds-hide');
      this.outcomeSummaryElement && this.outcomeSummaryElement.classList.add('slds-hide')
    } else {
      this.simulateBtn && this.simulateBtn.classList.add('slds-hide');
      this.outcomeSummaryElement && this.outcomeSummaryElement.classList.remove('slds-hide')
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

  assembleFilter() {
    try {
      this.initFilter();

      let dateFilterStr = this.filterFromElement &&
        this.filterFromElement.value &&
        this.filterFromElement.value != "null" &&
        `FROM:${this.filterFromElement.value}` || '';

      dateFilterStr += this.filterToElement &&
        this.filterToElement.value &&
        this.filterToElement.value != "null" &&
        `TO:${this.filterToElement.value}`;

      let filter = {};

      if (this.additionalFilter != null && this.additionalFilter != undefined && this.additionalFilter != '') {
        try {
          filter = Object.assign(filter, JSON.parse(this.additionalFilter));
        } catch (error) {
          console.error(error);
        }
      }

      if (dateFilterStr) {
        filter[this.dateField] = dateFilterStr;
      }

      if (Object.keys(filter) && Object.keys(filter).length) {
        this.filters = JSON.stringify(filter);
      } else {
        this.filters = null;
      }
    } catch (error) {
      console.error(error);
    }
  }

  handleFilter() {
    this.getRelatedRecords();
  }

  @track offset = 0; // Offset of the resulted records
  @track selectedOffset = 0; // Offset of the selected records
  @track disablePrevious = true; // Check if there's a Next page of records
  @track disableNext = true; // Check if there's a Next page of records
  @track recordsCount = 0;
  @track selectedRowsIds = [];
  selectedRowsDataMap = {};
  recordsIds; // Lists of recordsIds
  table;

  handlePrevious() {
    this.disablePrevious = true;
    this.disableNext = true;
    this.offset -= recordsPerPage;
    this.getRelatedRecords();
  }

  handleNext() {
    this.disableNext = true;
    this.disablePrevious = true;
    this.offset += recordsPerPage;
    this.getRelatedRecords();
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
    this.hasOutput = false;
    this.toggleRecordSelectionButton(false);
    this.toggleSimulateButton(true);
  }

/*   handleSelectedRecord(event){
    this.selectedRowsIds = event.detail.selectedRows;

    this.selectedRowsIds.forEach(function(row) {
      row.sobjectType = this.objectName;
    }.bind(this));

    this.hasSelectedRecords = this.selectedRowsIds && this.selectedRowsIds.length;
    this.toggleSimulateButton(this.hasSelectedRecords);
  } */

  handleSelectedRecord(event) {
    var addedRecords, removedRecords;

    // Get a list of current selected Ids
    let currentSelectionIds = [];
    let currentSelectionData = {};

    event.detail.selectedRows.forEach( row => {
      row.sobjectType = this.objectName;
      currentSelectionIds.push(row.Id);
      currentSelectionData[row.Id] = row;
    });

    // get the added records from the page
    addedRecords = [...new Set([...currentSelectionIds].filter(x => !((new Set(this.selectedRowsIds)).has(x))))];

    // get the removed records from the page
    removedRecords = [...new Set([...this.recordsIds].filter(x => !((new Set(currentSelectionIds)).has(x))))];
    // Remove them from the list
    removedRecords.forEach(function (item) {
      if (this.selectedRowsIds.includes(item)) {
        this.selectedRowsIds.splice(this.selectedRowsIds.indexOf(item), 1);
        delete this.selectedRowsDataMap[item];
      }
    }.bind(this));

    // Add them to the list
    this.selectedRowsIds.push(...addedRecords);

    // Add them to the Map
    addedRecords.forEach(function (item) {
      this.selectedRowsDataMap[item] = currentSelectionData[item];
    }.bind(this));

    // Update the list
    let tempDataList = [];
    this.selectedRowsIds.forEach(function (item) {
      tempDataList.push(this.selectedRowsDataMap[item]);
    }.bind(this));
    this.selectedRowsDataList = tempDataList;

    console.log(JSON.stringify(this.selectedRowsIds, null, 2));
    console.log(JSON.stringify(this.selectedRowsDataList, null, 2));

    this.hasSelectedRecords = this.selectedRowsIds && this.selectedRowsIds.length;
    this.toggleSimulateButton(this.hasSelectedRecords);
  }
}