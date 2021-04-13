import { LightningElement, track, api } from 'lwc';
import getRecords from '@salesforce/apex/SimpleSimulatorController.getRecords';
import translateIds from '@salesforce/apex/SimpleSimulatorController.translateIds';
import simulate from '@salesforce/apex/SimpleSimulatorController.simulate';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class CcSimpleSimulator extends LightningElement {

  @track member = {
    id: ''
  };
  @track hasMember = false;
  @track hasRecords = false;
  @track hasSelectedRecords = false;
  @track objectValue;
  @track output = '';
  @track filters = '';

  @track relatedRecords = [];
  @track relatedColumns = [];
  @track selectedIds;

  @track translate = false;
  @track showOutput = false;

  @api objectName;

  connectedCallback() {
    console.log(`objectName: ${this.objectName}`);
  }

  @api
  handleMemberChange(payload) {
    if (this.member.id !== payload.member.Id) {
      this.member = payload.member;
      this.member.id = this.member.Id;
      console.log(`member: " ${JSON.stringify(this.member, null, 2)}`);
      this.getRelatedRecords();
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

      console.log(
        JSON.stringify(this.relatedColumns, null, 2)
      )
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
      this.translate = this.template.querySelector('.fielo-translate-field').checked;

      console.log(`this.translate: ${this.translate}`);
      if (!this.translate) {
        this.output = output;
        this.showOutput = true;
        this.jsonToTable(JSON.parse(this.output));
      } else {
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
          console.error(error);
          const errorEvent = new ShowToastEvent({
            title: 'Translation Error',
            message: error && error.body && error.body.message || JSON.stringify(error),
            variant: 'error',
            mode: 'dismissable'
          });
          this.dispatchEvent(errorEvent);
        })
      }
    })
    .catch(error => {
      console.error(error);
      const errorEvent = new ShowToastEvent({
        title: 'Simulation Error',
        message: error && error.body && error.body.message || JSON.stringify(error),
        variant: 'error',
        mode: 'dismissable'
      });
      this.dispatchEvent(errorEvent);
    })
  }

  jsonToTable(result) {
    var rows = [];
    Object.keys(result).forEach(curr => {
      let records = result[curr].records;
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
          });
        });
      });
    });
  }
}