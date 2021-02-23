import { LightningElement, wire, api, track } from 'lwc';
import getRelatedLists from '@salesforce/apex/SimulatorService.getRelatedLists';
import getRecords from '@salesforce/apex/SimpleSimulatorController.getRecords';
import simulate from '@salesforce/apex/SimpleSimulatorController.simulate';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class BSimpleSimulator extends LightningElement {

    @track member;
    @track memberName;
    @track objectOptions = [];
    @track hasObjects = false;
    @track hasRecords = false;
    @track hasSelectedRecords = false;
    @track objectValue;
    @track output = '';

    @track relatedRecords = [];
    @track relatedColumns = [];
    @track selectedIds;

    handleLookupChange(e) {
        let lookupLwc = this.template.querySelector('c-b-lookup-field');
        this.member = lookupLwc.value;
        this.memberName = lookupLwc.selectedName;
        this.getRelated();
    }

    handleObjectChange(e) {
      this.objectValue = e.detail.value;
      this.getRelatedRecords();
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

    getRelated(){
      getRelatedLists({
        objectName: 'FieloPLT__Member__c'
      })
      .then(relatedLists => {
        relatedLists.forEach(function(rel) {
          this.objectOptions.push({
            label: rel.label,
            value: rel.name
          });
        }.bind(this));

        this.hasObjects = relatedLists && relatedLists.length;
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
        this.output = output;
      })
      .catch(error => {
        console.error(error);
        const errorEvent = new ShowToastEvent({
          title: 'Error',
          message: error && error.body && error.body.message || JSON.stringify(error),
          variant: 'error',
          mode: 'dismissable'
        });
        this.dispatchEvent(errorEvent);
      })
    }
}