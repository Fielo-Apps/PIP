public class SimpleSimulatorController {

    @AuraEnabled
    public static Object getPrograms(){
        try {
            List<FieloPLT__Program__c> programs = [SELECT Id, Name FROM FieloPLT__Program__c];

            return (Object) programs;
        } catch (Exception e) {
            ErrorService.insertError(e);
            return null;
        }
    }

    @AuraEnabled
    public static Object getRecords(String memberId, String objectName, String jsonFilter, String recordsPerPage, String offset){
        try {
            if (String.isBlank(recordsPerPage)) {
                recordsPerPage = '10';
            }

            if (String.isBlank(offset)) {
                offset = '0';
            }

            List<FieloPLT__Action__c> actions = (List<FieloPLT__Action__c>) Database.query(
                'SELECT Id, FieloPLT__CriteriaFields__c, FieloPLT__ConditionField__c, FieloPLT__ConditionValue__c, FieloPLT__ConditionType__c, FieloPLT__RuleTrigger__r.FieloPLT__Date__c, FieloPLT__RuleTrigger__r.FieloPLT__Object__c FROM FieloPLT__Action__c WHERE FieloPLT__RuleTrigger__r.FieloPLT__Object__c = :objectName'
            );

            List<String> actionFilters = new List<String>();

            String objectNameField = SObjectUtils.getNameField(objectName);

            Set<String> fields = new Set<String>{'Id',objectNameField};
            List<SimulatorService.CriteriaWrapper> criterias = new List<SimulatorService.CriteriaWrapper>();
            Map<String,SimulatorService.CriteriaWrapper> criteriasMetaDataMap;
            Map<String,Set<String>> fieldsByObject = new Map<String,Set<String>>();
            Map<String,Object> actionFilter = new Map<String,Object>();

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
                if (fieldsByObject.isEmpty()) {
                    switch on objectName {
                        when 'Opportunity' {
                            fieldsByObject.put(objectName, new Set<String>{objectNameField,'Amount','CloseDate','StageName'});
                        }
                        when 'Lead' {
                            fieldsByObject.put(objectName, new Set<String>{objectNameField,'CreatedDate','Status'});
                        }
                        when else {
                            fieldsByObject.put(objectName, new Set<String>{'Id',objectNameField});
                        }
                    }
                }

                Map<String, Schema.SObjectField> objectFields = ((sObject)Type.forName(objectName).newInstance()).getSObjectType().getDescribe().fields.getMap();

                for(FieloPLT__Action__c action : actions) {
                    if (String.isNotBlank(action.FieloPLT__ConditionField__c) && !fieldsByObject.isEmpty()) {
                        fieldsByObject.get(objectName).add(action.FieloPLT__ConditionField__c);

                        if (objectFields.get(action.FieloPLT__ConditionField__c).getDescribe().getType().name().tolowercase() == 'boolean') {
                            actionFilter = new Map<String,Object>{
                                action.FieloPLT__ConditionField__c => (Object) 'BOOLEAN:' + (action.FieloPLT__ConditionValue__c.tolowercase() == 'true' ? 'false' : 'true')
                            };
                        } else {
                            actionFilter = new Map<String,Object>{
                                action.FieloPLT__ConditionField__c => (Object) '!' + action.FieloPLT__ConditionValue__c
                            };
                        }

                        actionFilters.add(SimulatorService.getWhereCondition(JSON.serialize(actionFilter),objectName));
                    }
                    if (fieldsByObject.get(objectName) != null) {
                        fieldsByObject.get(objectName).add(action.FieloPLT__RuleTrigger__r.FieloPLT__Date__c);
                    } else {
                        fieldsByObject.put(objectName, new Set<String>{action.FieloPLT__RuleTrigger__r.FieloPLT__Date__c});
                    }
                }
            }

            if (fieldsByObject.isEmpty()) {
                switch on objectName {
                    when 'Opportunity' {
                        fieldsByObject.put(objectName, new Set<String>{objectNameField,'Amount','CloseDate','StageName'});
                    }
                    when 'Lead' {
                        fieldsByObject.put(objectName, new Set<String>{objectNameField,'CreatedDate','Status'});
                    }
                    when else {
                        fieldsByObject.put(objectName, new Set<String>{'Id',objectNameField});
                    }
                }
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
                    fieldDescribe = objectFields.get(fieldName)?.getDescribe();
                    if (fieldDescribe == null) continue;
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

            List<String> whereClauses = new List<String>{'(' + String.join(new List<String>(memberFilter), ' OR ') + ')'};

            if (!actionFilters.isEmpty()) {
                whereClauses.add('(' + String.join(new List<String>(actionFilters), ' OR ') + ')');
            }

            if (String.isNotBlank(jsonFilter)) {
                whereClauses.add(SimulatorService.getWhereCondition(jsonFilter,objectName));
            }

            String query = 'SELECT ' +
                String.join(new List<String>(fields), ', ') +
                ' FROM ' + objectName +
                ' WHERE ' + String.join(new List<String>(whereClauses), ' AND ') +
                ' ORDER BY LastModifiedDate DESC LIMIT ' + recordsPerPage + ' OFFSET ' + offset;

            return (Object) new Map<String, Object>{
                'columns' => (Object) columns,
                'records' => (Object) SObjectUtils.denormalizeRecords(Database.query(query))
            };
        } catch (Exception e) {
            ErrorService.insertError(e);
            return null;
        }
    }

    @AuraEnabled
    public static String simulate(String memberId, List<SObject> records){
        try {
            return JSON.serializePretty(FieloPLT.SimulationAPI.simulateRewarding(records, Id.valueOf(memberId), false));
        } catch (Exception e) {
            ErrorService.insertError(e);
            return null;
        }
    }

    @AuraEnabled
    public static object simulateAsync(String memberId, List<SObject> records){
        SimulationRequest__e payload = new SimulationRequest__e(
            Member__c = memberId,
            Records__c = JSON.serialize(records)
        );

        // Call method to publish events
        Database.SaveResult result = EventBus.publish(payload);
        String uuid = '';

        // Inspect publishing result for each event
        if (!result.isSuccess()) {
            ErrorService.insertErrors(result.getErrors());
        } else {
            uuid = EventBus.getOperationId(result);
        }
        return new Map<String, Object>{
            'payload' =>    (object) payload,
            'UUID' =>       (object) uuid
        };
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
                    Schema.DescribeSObjectResult objDescribe = objectToken.getDescribe();
                    String objectName = objDescribe.getName();

                    String nameField = SObjectUtils.getNameField(objectName);

                    if (objectToken == FieloPLT__ChallengeReward__c.sObjectType) {
                        nameField = 'FieloPLT__Challente__r.Name,FieloPLT__Mission__r.Name';
                    } else {
                        nameField = SObjectUtils.getNameField(objectName);
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
                    SObjectType objectType = Id.valueOf(record.Id).getSobjectType();

                    if (objectType == FieloPLT__ChallengeReward__c.sobjecttype) {
                        String missionName = String.valueOf(SObjectUtils.getFieldValue(record, 'FieloPLT__Mission__r.Name'));
                        String challengeName = String.valueOf(SObjectUtils.getFieldValue(record, 'FieloPLT__Challente__r.Name'));

                        translatedIds.put(String.valueOf(record.Id), String.isNotBlank(missionName) ? missionName : challengeName);
                    } else {
                        translatedIds.put(String.valueOf(record.Id), String.valueOf(record.get(nameField)));
                    }
                }
            }

            return (Object) translatedIds;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Object getConfiguration(String memberId, String objectName, String dateField){
        Map<String, Object> fieloConfig = new Map<String, Object>();

        Map<String,String> objectInfo = new Map<String,String>();

        DescribeSObjectResult objDescribe = ((sObject)Type.forName(objectName).newInstance()).getSObjectType().getDescribe();

        objectInfo.put('name', objDescribe.getName());
        objectInfo.put('label', objDescribe.getLabel());
        objectInfo.put('labelPlural', objDescribe.getLabelPlural());

        Map<String,String> dateFieldInfo = new Map<String,String>();

        DescribeFieldResult fieldDesc = objDescribe.fields.getMap().get(dateField).getDescribe();

        dateFieldInfo.put('name',fieldDesc.getName());
        dateFieldInfo.put('label',fieldDesc.getLabel());
        dateFieldInfo.put('type',fieldDesc.getType().name());

        fieloConfig.put('dateField', (object) dateFieldInfo);
        fieloConfig.put('objectInfo', (object) objectInfo);

        FieloPLT__Member__c member = [SELECT Id, FieloPLT__Program__c FROM FieloPLT__Member__c WHERE Id = :memberId];

        Map<String,Object> currencies = new Map<String,Object>();
        Map<String,Object> currenciesMap = new Map<String,Object>();
        for(FieloPLT__ProgramPointType__c ppt : [SELECT Id, FieloPLT__PointType__r.Name, FieloPLT__PointType__r.FieloPLT__DecimalsNumber__c, FieloPLT__PointType__r.FieloPLT__Symbol__c FROM FieloPLT__ProgramPointType__c WHERE FieloPLT__Program__c = :member.FieloPLT__Program__c]) {
            currencies.put(ppt.FieloPLT__PointType__r.Name, (Object) ppt.FieloPLT__PointType__r.FieloPLT__DecimalsNumber__c);
            currenciesMap.put(ppt.FieloPLT__PointType__r.Id, (Object) ppt.FieloPLT__PointType__r);
        }
        fieloConfig.put('currencies', (Object) currencies);
        fieloConfig.put('currenciesMap', (Object) currenciesMap);

        List<Map<String,Object>> columns = new List<Map<String,Object>>{
            new Map<String, Object> {
                'name' =>       (object) 'incentive',
                'fieldName' =>  (object) 'incentive',
                'type' =>       (object) 'text',
                'label' =>      (object) 'Incentive',
                'wrapText' =>   (object) true
            },
            new Map<String, Object> {
                'name'              => (object) 'eligibility',
                'fieldName'         => (object) 'eligibility',
                'type'              => (object) 'text',
                'label'             => (object) 'Eligibility Criteria to Meet',
                'wrapText'          => (object) true,
                'cellAttributes'    => (object) new Map<String, Object> {
                                        'iconName' => new Map<String, String> {
                                            'fieldName' => 'eligibleIcon'
                                        },
                                        'class' => 'fielo-color-icon'
                                    }
            },
            new Map<String, Object> {
                'name'              => (object) 'status',
                'fieldName'         => (object) 'status',
                'type'              => (object) 'text',
                'label'             => (object) 'Status',
                'cellAttributes'    => (object) new Map<String, Object> {
                                        'iconName' => new Map<String, String> {
                                            'fieldName' => 'incentiveEligibleIcon'
                                        },
                                        'class' => 'fielo-color-icon'
                                    }
            },
            new Map<String, Object> {
                'name' =>       (object) 'record',
                'fieldName' =>  (object) 'record',
                'type' =>       (object) 'text',
                'label' =>      (object) objDescribe.getLabel(),
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
    }

    @AuraEnabled
    public static Object getRecord(String recordId) {
        try {
            return SObjectSelector.getRecord(recordId);
        } catch (Exception e) {
            ErrorService.insertError(e);
            return null;
        }
    }

    public static List<FieloPLT__ProgramPointType__c> getSimulationCurrencies(Id programId, Id memberId, String objectName) {
        List<FieloPLT__SimulationSettings__c> settings = (List<FieloPLT__SimulationSettings__c>) Database.query(
            'SELECT Id, FieloPLT__Currencies__c, ' +
            ' FieloPLT__Segment__c ' +
            'FROM FieloPLT__SimulationSettings__c ' +
            'WHERE FieloPLT__Object__c = : objectName AND FieloPLT__Program__c = :programId'
        );
        Set<Id> currencyIds = new Set<Id>();
        Map<Id, Set<Id>> segmentsByMember = new Map<Id, Set<Id>>();
        List<FieloPLT__SimulationSettings__c> settingsWithSegment = new List<FieloPLT__SimulationSettings__c>();

        for (FieloPLT__SimulationSettings__c setting : settings) {
            if (setting.FieloPLT__Segment__c != null) {
                settingsWithSegment.add(setting);
                if (segmentsByMember.containsKey(memberId)) {
                    segmentsByMember.get(memberId).add(setting.FieloPLT__Segment__c);
                } else {
                    segmentsByMember.put(memberId, new Set<Id>{setting.FieloPLT__Segment__c});
                }
            } else {
                currencyIds.addAll((List<Id>)setting.FieloPLT__Currencies__c.split(','));
            }
        }

        // call segmentation api to get the correct simulation settings
        if (!settingsWithSegment.isEmpty()) {
            FieloPLT.SegmentService.verifySegments(segmentsByMember);
            for (FieloPLT__SimulationSettings__c setting : settingsWithSegment) {
                if (setting.FieloPLT__Segment__c != null && segmentsByMember.get(memberId)?.contains(setting.FieloPLT__Segment__c) == true) {
                    currencyIds.addAll((List<Id>)setting.FieloPLT__Currencies__c.split(','));
                    break;
                }
            }
        }

        return [
            SELECT
                Id,
                FieloPLT__PointType__r.Name,
                FieloPLT__PointType__r.FieloPLT__DecimalsNumber__c,
                FieloPLT__PointType__r.FieloPLT__Symbol__c
            FROM FieloPLT__ProgramPointType__c
            WHERE FieloPLT__Program__c = :programId
            AND FieloPLT__PointType__c IN :currencyIds
        ];
    }
}