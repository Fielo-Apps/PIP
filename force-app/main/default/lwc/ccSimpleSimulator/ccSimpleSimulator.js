import { LightningElement, track, wire } from 'lwc';
import getRelatedLists from '@salesforce/apex/SimulatorService.getRelatedLists';
import getRecords from '@salesforce/apex/SimpleSimulatorController.getRecords';
import translateIds from '@salesforce/apex/SimpleSimulatorController.translateIds';
import simulate from '@salesforce/apex/SimpleSimulatorController.simulate';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { registerListener, unregisterAllListeners, fireEvent } from 'c/pubsub';
import { CurrentPageReference } from 'lightning/navigation';

export default class BSimpleSimulator extends LightningElement {

  @track member;
  @track program;
  @track programs;
  @track programName;
  @track objectOptions = [];
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

  @wire(CurrentPageReference) pageRef;

  connectedCallback() {
    // subscribe to memberChange event
    registerListener('fieloplt:memberChange', this.handleMemberChange, this);

    console.log('subscribed to memberChange evt');

    if (this.member != null && this.member.id === '') {
      // be sure to show the spinner
      this.loaded = false;
      fireEvent(this.pageRef, 'fieloplt:getMember', '');
    }
  }

  handleMemberChange(payload) {
    console.log('member changed');
    if (this.member.id !== payload.member.Id) {
      this.member = payload.member;
      this.member.id = this.member.Id;
      console.log(`Selected member" ${this.member}`);
    }
  }


  getRelatedRecords(){
    getRecords({
      memberId: this.member,
      objectName: this.objectValue
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
      memberId: this.member,
      records: this.selectedIds
    })
    .then(output => {
      this.translate = this.template.querySelector('.fielo-translate-field').checked;

      console.log(`this.translate: ${this.translate}`);
      if (!this.translate) {
        this.output = output;
        this.showOutput = true;
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
}