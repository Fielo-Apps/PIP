public class SimpleSimulatorController {

    @AuraEnabled
    public static Object getPrograms(){
        List<FieloPLT__Program__c> programs = [SELECT Id, Name FROM FieloPLT__Program__c];

        return (Object) programs;
    }

    @AuraEnabled
    public static Object getRecords(String memberId, String objectName, String jsonFilter, String recordsPerPage, String offset){

        List<FieloPLT__Action__c> actions = (List<FieloPLT__Action__c>) Database.query(
            'SELECT Id, FieloPLT__CriteriaFields__c, FieloPLT__ConditionField__c, FieloPLT__ConditionValue__c, FieloPLT__ConditionType__c, FieloPLT__RuleTrigger__r.FieloPLT__Date__c FROM FieloPLT__Action__c WHERE FieloPLT__RuleTrigger__r.FieloPLT__Object__c = :objectName'
        );

        List<String> actionFilters = new List<String>();

        Set<String> fields = new Set<String>{'Id','Name'};
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
                        fieldsByObject.put(objectName, new Set<String>{'Name','Amount','CloseDate','StageName'});
                    }
                    when 'Lead' {
                        fieldsByObject.put(objectName, new Set<String>{'Name','CreatedDate','Status'});
                    }
                    when else {
                        fieldsByObject.put(objectName, new Set<String>{'Id','Name'});
                    }
                }
            }
            for(FieloPLT__Action__c action : actions) {
                if (String.isNotBlank(action.FieloPLT__ConditionField__c) && !fieldsByObject.isEmpty()) {
                    fieldsByObject.get(objectName).add(action.FieloPLT__ConditionField__c);

                    actionFilter = new Map<String,Object>{
                        action.FieloPLT__ConditionField__c => (Object) '!' + action.FieloPLT__ConditionValue__c
                    };

                    actionFilters.add(getWhereCondition(JSON.serialize(actionFilter),objectName));
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
                    fieldsByObject.put(objectName, new Set<String>{'Name','Amount','CloseDate','StageName'});
                }
                when 'Lead' {
                    fieldsByObject.put(objectName, new Set<String>{'Name','CreatedDate','Status'});
                }
                when else {
                    fieldsByObject.put(objectName, new Set<String>{'Id','Name'});
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
            whereClauses.add(getWhereCondition(jsonFilter,objectName));
        }

        String query = 'SELECT ' +
            String.join(new List<String>(fields), ', ') +
            ' FROM ' + objectName +
            ' WHERE ' + String.join(new List<String>(whereClauses), ' AND ') +
            ' ORDER BY LastModifiedDate DESC LIMIT ' + recordsPerPage + ' OFFSET ' + offset;

        System.debug('query: ' + query.replace('FROM','\nFROM\n').replace('WHERE','\nWHERE\n'));

        return (Object) new Map<String, Object>{
            'columns' => (Object) columns,
            'records' => (Object) Database.query(query)
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
    public static Object getConfiguration(String memberId, String objectName, String dateField){
        try {
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
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    private static string getWhereCondition(String filterJson, String objectName) {
        Map<String, Schema.SObjectField> objectFields = ((sObject)Type.forName(objectName).newInstance()).getSObjectType().getDescribe().fields.getMap();

        List<String> conditions = new List<String>();
        List<String> innerConditions = new List<String>();
        if (String.isNotBlank(filterJson) && filterJson != null ) {
            Map<String,Object> filter = (Map<String, Object>) JSON.deserializeUntyped( filterJson);
            for ( String k :filter.keySet() ) {
                String whereCondition = '';
                String value = string.valueOf(filter.get(k));
                if (value == null || value == 'null') {
                    whereCondition = String.escapeSingleQuotes(k) + ' = null';
                } else if(value.toLowerCase() == '!null') {
                    whereCondition = String.escapeSingleQuotes(k) + ' != null';
                } else {
                    if(value.startsWith('BOOLEAN:')){
                            whereCondition = String.escapeSingleQuotes(k) + ' = ' +  String.escapeSingleQuotes(value.removeStart('BOOLEAN:'));
                    } else if(value.startsWith('LIKE:')){
                            if (objectName.toLowerCase() == 'fieloplt__member__c' && String.escapeSingleQuotes(k).toLowerCase() == 'name') {
                                whereCondition = '(' + String.escapeSingleQuotes(k) + ' LIKE \'%' +  String.escapeSingleQuotes(value.removeStart('LIKE:')) + '%\'' +
                                ' OR FieloPLT__Email__c LIKE \'%' +  String.escapeSingleQuotes(value.removeStart('LIKE:')) + '%\') ';
                            } else {
                                whereCondition = String.escapeSingleQuotes(k) + ' LIKE \'%' +  String.escapeSingleQuotes(value.removeStart('LIKE:')) + '%\'';
                            }
                    } else if ( value.startsWith('!') ) {
                            whereCondition = String.escapeSingleQuotes(k) + ' <> \'' +  String.escapeSingleQuotes(value.substring(1)) + '\'';
                    } else if ( value.startsWith('IN:') ) {
                            string value2 = value.removeStart('IN:');
                            List<String> ids = new List<String>();

                            for(String str: value2.split(',')){
                                string strc = '\'' + str  + '\'';
                                ids.add(strc);
                            }
                            whereCondition += String.escapeSingleQuotes(k) + ' IN ' + ids;
                    } else if ( value.startsWith('FROM:') ) {
                        value = value.removeStart('FROM:');

                        if (objectFields.get(k).getDescribe().getSOAPType().name().tolowercase() == 'double') {
                            List<String> numbers = new List<String>();

                            if (value.contains('TO:')) {
                                numbers = value.split('TO:');
                            } else {
                                numbers.add(value);
                            }

                            innerConditions = new List<String>();
                            for (Integer i = 0; i < numbers.size(); i++) {
                                whereCondition = String.escapeSingleQuotes(k);
                                if (i == 0) {
                                    // FROM
                                    whereCondition += ' >= ';
                                } else {
                                    // TO
                                    whereCondition += ' <= ';
                                }
                                whereCondition += numbers[i];
                                innerConditions.add(whereCondition);
                            }
                            whereCondition = String.join(innerConditions, ' AND ');
                        } else {
                            Date tempDate = Date.today();
                            DateTime tempDateTime = DateTime.newInstance(0);
                            List<String> dates = new List<String>();

                            if (value.contains('TO:')) {
                                dates = value.split('TO:');
                            } else {
                                dates.add(value);
                            }

                            innerConditions = new List<String>();
                            for (Integer i = 0; i < dates.size(); i++) {
                                tempDate = Date.valueOf(dates[i]);
                                tempDateTime = DateTime.newInstance(tempDate.year(), tempDate.month(), tempDate.day());

                                whereCondition = String.escapeSingleQuotes(k);
                                if (i == 0) {
                                    // FROM
                                    whereCondition += ' >= ';
                                } else {
                                    // TO
                                    whereCondition += ' <= ';
                                }
                                if (objectFields.get(k).getDescribe().getType().name().tolowercase() == 'datetime') {
                                    whereCondition += tempDateTime.format('yyyy-MM-dd\'T00:00:00Z\'');
                                } else {
                                    whereCondition += tempDateTime.format('yyyy-MM-dd');
                                }
                                innerConditions.add(whereCondition);
                            }
                            whereCondition = String.join(innerConditions, ' AND ');
                        }
                    } else if ( value.startsWith('TO:') ) {
                        Date tempDate = Date.valueOf(value.removeStart('TO:'));
                        DateTime tempDateTime = DateTime.newInstance(tempDate.year(), tempDate.month(), tempDate.day());

                        whereCondition = String.escapeSingleQuotes(k) + ' <= ' + tempDateTime.format('yyyy-MM-dd\'T00:00:00Z\'') ;
                    } else if ( objectName.tolowercase() == 'FieloPLT__Reward__c' && k.tolowercase() == 'fieloplt__program__c'){
                            whereCondition = '( ' +
                                String.escapeSingleQuotes(k) + ' = \'' +  String.escapeSingleQuotes(value) + '\' OR ' +
                                String.escapeSingleQuotes(k) + ' = null ' +
                                ')';
                    } else {
                            whereCondition = String.escapeSingleQuotes(k) + ' = \'' +  String.escapeSingleQuotes(value) + '\'';
                    }
                }
                if (String.isNotBlank(whereCondition)) {
                    conditions.add(whereCondition);
                }
            }
        }
        return String.join(conditions, ' AND ');
    }
}