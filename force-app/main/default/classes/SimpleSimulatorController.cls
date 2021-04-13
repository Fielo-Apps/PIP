public class SimpleSimulatorController {

    @AuraEnabled
    public static Object getPrograms(){
        List<FieloPLT__Program__c> programs = [SELECT Id, Name FROM FieloPLT__Program__c];

        return (Object) programs;
    }

    @AuraEnabled
    public static Object getRecords(String memberId, String objectName){

        List<FieloPLT__Action__c> actions = (List<FieloPLT__Action__c>) Database.query(
            'SELECT Id, FieloPLT__CriteriaFields__c FROM FieloPLT__Action__c WHERE FieloPLT__RuleTrigger__r.FieloPLT__Object__c = :objectName'
        );


        Set<String> fields = new Set<String>{'Id','Name'};
        List<SimulatorService.CriteriaWrapper> criterias = new List<SimulatorService.CriteriaWrapper>();
        Map<String,SimulatorService.CriteriaWrapper> criteriasMetaDataMap;
        Map<String,Set<String>> fieldsByObject = new Map<String,Set<String>>();
        if (!actions.isEmpty()) {
            for(FieloPLT__Action__c action : actions) {
                if (String.isNotBlank(action.FieloPLT__CriteriaFields__c)) {
                    criteriasMetaDataMap = (Map<String,SimulatorService.CriteriaWrapper>)JSON.deserialize(action.FieloPLT__CriteriaFields__c, Map<String,SimulatorService.CriteriaWrapper>.class);

                    if(criteriasMetaDataMap.containsKey('rules'))
                        criterias.add(criteriasMetaDataMap.get('rules'));

                    if(criteriasMetaDataMap.containsKey('missions'))
                        criterias.add(criteriasMetaDataMap.get('missions'));
                }
            }

            fieldsByObject = SimulatorService.getFieldsMap(criterias);
        }

        if (fieldsByObject.isEmpty()) {
            fieldsByObject.put(objectName, new Set<String>{'Id','Name'});
        }

        List<Map<String,Object>> columns = new List<Map<String,Object>>();

        Map<String, Schema.SObjectField> objectFields = ((sObject)Type.forName(objectName).newInstance()).getSObjectType().getDescribe().fields.getMap();

        Set<String> memberFilter = new Set<String>();
        for (SObjectField fieldToken : objectFields.values()) {
            if(fieldToken.getDescribe().getType().name().toLowerCase() == 'reference' && fieldToken.getDescribe().getReferenceTo().get(0).getDescribe().getName() == 'FieloPLT__Member__c') {
                memberFilter.add(fieldToken.getDescribe().getName() + ' = :memberId');
            }
        }

        String fieldType;
        Map<String,Object> col;
        Schema.DescribeFieldResult fieldDescribe;
        Set<String> fieldsToAdd = new Set<String>();
        for (String fieldName : fieldsByObject.get(objectName)) {
            if (fieldName != 'FieloPLT__Member__c' && fieldName.containsNone('.')) {
                fieldDescribe = objectFields.get(fieldName).getDescribe();
                fieldType = fieldDescribe.getType().name().toLowerCase();

                col = new Map<String,Object>();
                col.put('name', (Object) fieldName);
                col.put('fieldName', (Object) fieldName);
                col.put('apexType', (Object) fieldType);

                if (fieldName.contains('.')) {
                    col.put('label', SimulatorService.getPathLabel(objectName, fieldName));
                } else {
                    col.put('label', (Object) fieldDescribe.getLabel());
                }

                switch on fieldType {
                    when 'text' {
                        col.put('type', (Object) 'text');
                        col.put('wrapText', (Object) true);
                    }
                    when 'percent' {
                        col.put('type', (Object) 'percent');
                    }
                    when 'currency' {
                        col.put('type', (Object) 'currency');
                        col.put('typeAttributes', (Object) new Map<String, String>{
                            'currencyCode' => 'USD'
                        });
                        col.put('cellAttributes', (Object) new Map<String, String>{
                            'alignment' => 'left'
                        });
                    }
                    when 'double','integer','decimal' {
                        col.put('type', (Object) 'number');
                        col.put('typeAttributes', (Object) new Map<String, String>{
                            'minimumFractionDigits' => String.valueOf(fieldDescribe.getScale())
                        });
                        col.put('cellAttributes', (Object) new Map<String, String>{
                            'alignment' => 'left'
                        });
                    }
                    when 'reference' {
                        String nameField = fieldDescribe.getRelationshipName() + '.' +
                            (
                                fieldDescribe.getReferenceTo() != null && !fieldDescribe.getReferenceTo().isEmpty() ?
                                SimulatorService.getNameField(fieldDescribe.getReferenceTo()[0].getDescribe()) :
                                ''
                            );
                        col.put('type', (Object) 'text');
                        col.put('fieldName', (Object) nameField.replaceAll('\\.','_'));
                        fieldsToAdd.add(nameField);
                    }
                    when 'date' {
                        col.put('type', (Object) 'date');
                        col.put('typeAttributes', (Object) new Map<String, String>{
                            'timeZone' => 'UTC',
                            'year' => 'numeric',
                            'month' => 'numeric',
                            'day' => 'numeric'
                        });
                    }
                    when 'datetime' {
                        col.put('type', (Object) 'date');
                        col.put('typeAttributes', (Object) new Map<String, Object>{
                            'timeZone' => (Object) 'UTC',
                            'year' => (Object) 'numeric',
                            'month' => (Object) 'numeric',
                            'day' => (Object) 'numeric',
                            'hour' => (Object) '2-digit',
                            'minute' => (Object) '2-digit',
                            'hour12' => (Object) true
                        });
                    }
                }
                columns.add(col);
            }
        }

        fields.addAll(fieldsToAdd);
        fields.addAll(fieldsByObject.get(objectName));

        fields = SimulatorService.deleteDuplicateFields(fields);

        return (Object) new Map<String, Object>{
            'columns' => (Object) columns,
            'records' => (Object) Database.query('SELECT ' + String.join(new List<String>(fields), ', ') + ' FROM ' + objectName + ' WHERE ' + String.join(new List<String>(memberFilter), ' OR ') + ' ORDER BY LastModifiedDate DESC LIMIT 10')
        };
    }

    @AuraEnabled
    public static String simulate(String memberId, List<SObject> records){
        return JSON.serializePretty(FieloPLT.SimulationAPI.simulateRewarding(records, Id.valueOf(memberId), false));
    }

    @AuraEnabled
    public static Object translateIds(List<String> idsToTranslate){
        try {
            Map<String, Map<String, Set<Id>>> idsByObject = new Map<String, Map<String, Set<Id>>>();
            Map<SObjectType, Map<String, String>> objectInfoMap = new Map<SObjectType, Map<String, String>>();

            for (String singleId : idsToTranslate) {
                SObjectType objectToken = Id.valueOf(singleId).getSobjectType();

                Map<String, String> objectInfo = objectInfoMap.get(objectToken);

                if (objectInfo == null) {
                    Schema.DescribeSObjectResult objDescribe = Id.valueOf(singleId).getSobjectType().getDescribe();
                    String objectName = objDescribe.getName();

                    String nameField;
                    for (SObjectField fieldToken : objDescribe.fields.getMap().values()) {
                        if (fieldToken.getDescribe().isNameField()) {
                            nameField = fieldToken.getDescribe().getName();
                        }
                    }

                    objectInfo = new Map<String,String>{
                        'objectName' => objectName,
                        'nameField' => nameField
                    };

                    objectInfoMap.put(objectToken, objectInfo);
                }

                if (idsByObject?.get(objectInfo.get('objectName'))?.get(objectInfo.get('nameField')) != null) {
                    idsByObject.get(objectInfo.get('objectName')).get(objectInfo.get('nameField')).add(Id.valueOf(singleId));
                } else {
                    idsByObject.put(objectInfo.get('objectName'), new Map<String, Set<Id>>{
                        objectInfo.get('nameField') => new Set<Id>{Id.valueOf(singleId)}
                    });
                }
            }

            Map<String, String> translatedIds = new Map<String, String>();


            for (String objectName : idsByObject.keySet()) {
                String nameField = new List<String>(idsByObject.get(objectName).keySet())[0];

                Set<Id> idsToQuery = idsByObject.get(objectName).get(nameField);

                for(SObject record : Database.query('SELECT Id, ' + nameField + ' FROM ' + objectName + ' WHERE Id in : idsToQuery')){
                    translatedIds.put(String.valueOf(record.Id), String.valueOf(record.get(nameField)));
                }
            }

            return (Object) translatedIds;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Object getConfiguration(String memberId){
        try {
            Map<String, Object> fieloConfig = new Map<String, Object>();

            FieloPLT__Member__c member = [SELECT Id, FieloPLT__Program__c FROM FieloPLT__Member__c WHERE Id = :memberId];

            Map<String,Object> currencies = new Map<String,Object>();
            for(FieloPLT__ProgramPointType__c ppt : [SELECT Id, FieloPLT__PointType__r.Name, FieloPLT__PointType__r.FieloPLT__DecimalsNumber__c FROM FieloPLT__ProgramPointType__c WHERE FieloPLT__Program__c = :member.FieloPLT__Program__c]) {
                currencies.put(ppt.FieloPLT__PointType__r.Name, (Object) ppt.FieloPLT__PointType__r.FieloPLT__DecimalsNumber__c);
            }
            fieloConfig.put('currencies', (Object) currencies);

            List<Map<String,Object>> columns = new List<Map<String,Object>>{
                new Map<String, Object> {
                    'name' =>       (object) 'incentive',
                    'fieldName' =>  (object) 'incentive',
                    'type' =>       (object) 'text',
                    'label' =>      (object) 'Incentive',
                    'wrapText' =>   (object) true
                },
                new Map<String, Object> {
                    'name' =>       (object) 'status',
                    'fieldName' =>  (object) 'status',
                    'type' =>       (object) 'text',
                    'label' =>      (object) 'Status'
                },
                new Map<String, Object> {
                    'name' =>       (object) 'record',
                    'fieldName' =>  (object) 'record',
                    'type' =>       (object) 'text',
                    'label' =>      (object) 'Record',
                    'wrapText' =>   (object) true
                }
            };

            for (String name : currencies.keySet()) {
                columns.add(
                    new Map<String, Object> {
                        'name' =>           (object) name,
                        'fieldName' =>      (object) name,
                        'type' =>           (object) 'number',
                        'label' =>          (object) name,
                        'typeAttributes' => (object) new Map<String, String>{
                                                'minimumFractionDigits' => String.valueOf(currencies.get(name))
                                            },
                        'cellAttributes' => (object) new Map<String, String>{
                                                'alignment' => 'left'
                                            }
                    }
                );
            }

            fieloConfig.put('columns', columns);

            return fieloConfig;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}