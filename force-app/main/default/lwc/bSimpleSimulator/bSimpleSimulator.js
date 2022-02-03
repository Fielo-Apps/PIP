import { LightningElement, wire, api, track } from 'lwc';
import getRelatedLists from '@salesforce/apex/SimulatorService.getRelatedLists';
import getPrograms from '@salesforce/apex/SimpleSimulatorController.getPrograms';
import getRecords from '@salesforce/apex/SimpleSimulatorController.getRecords';
import translateIds from '@salesforce/apex/SimpleSimulatorController.translateIds';
import simulate from '@salesforce/apex/SimpleSimulatorController.simulate';
import simulateAsync from '@salesforce/apex/SimpleSimulatorController.simulateAsync';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { subscribe, unsubscribe, onError, setDebugFlag, isEmpEnabled } from 'lightning/empApi';

export default class BSimpleSimulator extends LightningElement {
    channelName = '/event/PipSim__SimulationResult__e';
    subscription;
    isSubscribeDisabled = false;
    isUnsubscribeDisabled = !this.isSubscribeDisabled;

    @track member;
    @track memberName;
    @track program;
    @track programs;
    @track programName;
    @track objectOptions = [];
    @track isLoading = false;
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

    @api simulationMode;

    connectedCallback() {
      this.registerErrorListener();
      this.doSubscribe();

      this.isLoading = true;
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
        this.isLoading = false;
      })
      .catch(error => {
        this.isLoading = false;
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
        objectName: this.objectValue,
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
      this.isLoading = true;
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
        this.isLoading = false;
      })
      .catch(error => {
        this.isLoading = false;
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
      if (this.simulationMode == 'Sync') {
        this.isLoading = true;
        simulate({
          memberId: this.member,
          records: this.selectedIds
        })
        .then(output => {
          this.setOutput(output);
          this.isLoading = false;
        })
        .catch(error => {
          this.isLoading = false;
          console.error(error);
          const errorEvent = new ShowToastEvent({
            title: 'Simulation Error',
            message: error && error.body && error.body.message || JSON.stringify(error),
            variant: 'error',
            mode: 'dismissable'
          });
          this.dispatchEvent(errorEvent);
        })
      } else {
        this.isLoading = true;
        this.callSimulateAsync();
      }
    }

    setOutput(output) {
      try {
        this.translate = this.template.querySelector('.fielo-translate-field').checked;

        if (!this.translate) {
          this.output = JSON.stringify(JSON.parse(output), null, 2);
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
            this.output = JSON.stringify(JSON.parse(outputStr), null, 2);;
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
      } catch (error) {
        console.error(error);
      }
    }

    simulationRequest;
    async callSimulateAsync() {
      this.simulationRequest = await simulateAsync({memberId: this.member,records: this.selectedIds});
    }

    registerErrorListener() {
        // Invoke onError empApi method
        onError(error => {
            this.isLoading = false;
            console.log('Received error from server: ', JSON.stringify(error));
        });
    }

    // Handles subscribe button click
    async doSubscribe() {
        var subscriptionResponse = await subscribe(
            this.channelName,
            -1,
            function(response) {
                this.isLoading = false;
                // Response contains the subscription information on subscribe call
                console.log('New message received: ', JSON.stringify(response.data, null, 2));

                if (response && response.data && response.data.payload && response.data.payload.PipSim__Result__c) {
                  this.setOutput(response.data.payload.PipSim__Result__c);
                }
            }.bind(this)
        );
        this.subscription = subscriptionResponse;
    }

    disconnectedCallback(){
    unsubscribe(this.subscription, response => {
      console.log('unsubscribe() response: ', JSON.stringify(response));
      // Response is true for successful unsubscribe
    });
  }
}