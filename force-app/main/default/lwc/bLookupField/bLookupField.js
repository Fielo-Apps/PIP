import { LightningElement, track, wire, api } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getRecords from '@salesforce/apex/SimulatorService.getWiredRecords';

export default class BLookupField extends LightningElement {

    @api sObjectName = 'FieloPLT__Member__c';
    @api fieldName;
    @api fieldLabel;
    @api typeAttributes;
    @api referenceToNameField;

    @track finalOptions;
    @track selectedId;
    @track items;
    @track hasOptions = false;
    firstLoad = true;
    fieldType = 'reference';

    @track hasLabel = true;
    variant;

    initSet = false;
    componentLoaded = false;

    @api
    get value() {
        return this.selectedId;
    };

    set value(value) {
        this.selectedId = value;
    };

    _selectedName;
    @api
    get selectedName() {
        return this._selectedName;
    };

    set selectedName(value) {
        this._selectedName = value;
    };

    @api
    get type() {
        return this.fieldType;
    };

    set type(value) {
        this.fieldType = value;
    };

    @api
    get name() {
        return this.fieldName;
    };

    handleItemRemove(event) {
        this.items = [];
        this.template.querySelector('.selected-record').classList.add('slds-hide');
        this.template.querySelector('.search-input').classList.remove('slds-hide');
        this.selectedId = "";
        this.dispatchEvent(new Event('change'));
    }

    handleSearch(event) {
        event.stopPropagation();
        let searchValue = this.template.querySelector(".search-input").value;

        if (searchValue.length >= 3) {
            console.log(JSON.stringify(searchValue,null,2));
            this.dataFilters = JSON.stringify(Object.assign(JSON.parse(this.dataFilters || '{}'), {[this.referenceToNameField]: "LIKE:"+searchValue}));
            this.firstLoad = false;
            refreshApex(this.wiredResult);
        } else if (!searchValue) {
            this.finalOptions = [];
        }
    }

    handleLookupSelect(event) {
        try{
            this.selectedId = event.detail.name;
            this.setSelected();
        } catch(e) {
            console.error(e);
        }
    }

    setSelected() {
        try {
            if (this.template.querySelector('.fielo-lookup-results')) {
                this.template.querySelector('.fielo-lookup-results').classList.add('slds-hide');

                this.selectedName = this.finalOptions.filter(function (option) {
                    return option.Id == this.selectedId;
                }.bind(this))[0].Name;

                this.items = [{
                    label: this.selectedName,
                    name: this.selectedId
                }];

                this.template.querySelector(".search-input").value = "";
                this.template.querySelector('.search-input').classList.add('slds-hide');
                this.template.querySelector('.selected-record').classList.remove('slds-hide');

                this.initSet = true;
                this.componentLoaded = true;

                this.dispatchEvent(new Event('change'));
            }
        } catch(e) {
            console.error(e);
        }
    }

    wiredResult;

    @wire(
        getRecords,
        {
            fields: '$referenceToNameField',
            objectName: '$sObjectName',
            dataFilters: '$dataFilters',
            recordsPerPage: 5,
            offset: 0
        })
    recordsResults(value) {
        try{
            this.wiredResult = value;
            const { error, data } = value;
            if (data) {
                let results = data;
                results = results.map(option => {
                    if(option.Title && !option.Name){
                        return Object.assign({}, option, { Name: option.Title })
                    } else {
                        return option;
                    }
                })
                this.finalOptions = results;
                if ( this.finalOptions && this.finalOptions.length) {
                    this.hasOptions = true;
                    if (!this.firstLoad) {
                        this.template.querySelector('.fielo-lookup-results').classList.remove('slds-hide');
                    }
                }
                if (this.selectedId) {
                    this.setSelected();
                }
            } else if (error) {
                console.log(error);
            }
        } catch(e) {
            console.error(e);
        }
    }

    connectedCallback() {
        try {
            if (this.typeAttributes) {
                for (const attribute in this.typeAttributes) {
                    if (this.typeAttributes.hasOwnProperty(attribute)) {
                        this[attribute] = this.typeAttributes[attribute]
                    }
                }
                if (this.variant && this.variant == 'label-hidden') {
                    this.hasLabel = false;
                  }
            }

            if (this._allValues && Object.keys(this._allValues).length) {
                if (this._allValues[this.fieldName]) {
                    this.selectedId = this._allValues[this.fieldName];
                }
            }

            if (this.selectedId) {
                refreshApex(this.wiredResult);
            }
        } catch(e) {
            console.error(e);
        }
    }

    renderedCallback() {
        if(!this.componentLoaded){
            try{
                if (this.selectedId && !this.initSet) {
                    this.setSelected();
                }
            } catch(e) {
                console.error(e);
            }
        }
    }

    _allValues;

    @api
    get allValues() {
        return this._allValues;
    }

    set allValues(value) {
        this._allValues = value;
        this.initSet = false;

        if (this._allValues && Object.keys(this._allValues).length) {
            if (this._allValues[this.fieldName]) {
                this.selectedId = this._allValues[this.fieldName];
            }
        }

        if (this.selectedId) {
            refreshApex(this.wiredResult);
        }

        if (this.variant && this.variant == 'label-hidden') {
            this.hasLabel = false;
        }
    }

    @track dataFilters = '{}';

    @api
    get filters() {
        return this. dataFilters;
    }

    set filters(value) {
        this.dataFilters = value || '{}';
    }

}