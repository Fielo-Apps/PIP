import { LightningElement, wire, api, track } from 'lwc';
import getRelatedLists from '@salesforce/apex/SimulatorService.getRelatedLists';
import getPrograms from '@salesforce/apex/SimpleSimulatorController.getPrograms';
import getRecords from '@salesforce/apex/SimpleSimulatorController.getRecords';
import translateIds from '@salesforce/apex/SimpleSimulatorController.translateIds';
import simulate from '@salesforce/apex/SimpleSimulatorController.simulate';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class BSimpleSimulator extends LightningElement {

    @track member;
    @track memberName;
    @track program;
    @track programs;
    @track programName;
    @track objectOptions = [];
    @track hasPrograms = false;
    @track hasProgram = false;
    @track hasObjects = false;
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

    connectedCallback() {
      getPrograms()
      .then(result => {
        this.programs = [];
        result.forEach(function(record) {
          this.programs.push({
            label: record.Name,
            value: record.Id
          });
        }.bind(this))

        this.hasPrograms = this.programs && this.programs.length;
      })
      .catch(error => {
        console.error(error);
      })
    }

    handleProgramChange(e) {
        let lookupLwc = this.template.querySelector('.fielo-field__program');
        this.program = lookupLwc.value;
        this.programName = lookupLwc.selectedName;
        this.hasProgram = true;
        this.filters = JSON.stringify({FieloPLT__Program__c:this.program});
    }

    handleMemberChange(e) {
        let lookupLwc = this.template.querySelector('.fielo-field__member');
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