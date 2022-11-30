public without sharing class SimulatorService {
    public static Map<String,Set<String>> getFieldsMap(List<CriteriaWrapper> criterias){
        Map<String,Set<String>> fieldsMap = new Map<String,Set<String>>();
        for(CriteriaWrapper cw : criterias){
            for(String objectType : cw.fieldsByObject.keySet()){
                Set<String> fields = cw.fieldsByObject.get(objectType);
                if(fields.isEmpty()){
                    fields.add('Id');
                }

                if(fieldsMap.containsKey(objectType)){
                    fieldsMap.get(objectType).addAll(fields);
                }else{
                    fieldsMap.put(objectType, new Set<String>(fields));
                }
            }
        }
        return fieldsMap;
    }

    public static final string EMPTY_SPACES_REGEXP = '\\s(?![^\\(]*\\))';

    public static set<String> deleteDuplicateFields(Set<String> fields){
        return SObjectUtils.deleteDuplicateFields(fields);
    }

    public static string getPathLabel(String objectName, String path) {
        Schema.DescribeSObjectResult describe = ((sObject)Type.forName(objectName).newInstance()).getSObjectType().getDescribe();

        if (path.contains('.')) {
            List<String> fieldPath = path.split('\\.');
            String relationShipName = fieldPath.remove(0);
            string fieldName = relationShipName.endsWith('__r') ? relationShipName.replace('__r','__c') : relationShipName + 'Id';
            return getPathLabel(
                describe.fields.getMap().get(fieldName).getDescribe().getReferenceTo().get(0).getDescribe().getName(),
                String.join(fieldPath,'.')
            );
        } else {
            if (!describe.fields.getMap().get(path).getDescribe().getLabel().trim().startsWith(describe.getLabel())) {
                return describe.getLabel() + ' ' + describe.fields.getMap().get(path).getDescribe().getLabel();
            } else {
                return describe.fields.getMap().get(path).getDescribe().getLabel();
            }
        }
    }

    public static string getNameField(Schema.DescribeSObjectResult dsr) {
        if (dsr != null) {
            for(Schema.SObjectField field : dsr.fields.getMap().values()) {
                if (field.getDescribe().isNameField()) {
                    return field.getDescribe().getName();
                }
            }
        }
        return null;
    }

    @AuraEnabled
    public static List<Map<String,String>> getRelatedLists(String objectName, String context) {
        List<Map<String,String>> lista = new List<Map<String,String>>();
        Schema.DescribeSObjectResult describeResult = ((sObject)Type.forName(objectName).newInstance()).getSObjectType().getDescribe();
        List<String> labels = new List<String>();
        Map<String, Schema.ChildRelationship> childRelationshipsMap = new Map<String, Schema.ChildRelationship>();
        Map<String,Boolean> labelsMap = new Map<String,Boolean>();
        for(Schema.ChildRelationship thisChild : describeResult.getChildRelationships()){
            if(thisChild.getRelationshipName() != null){
                String relatedObject = String.valueOf(thisChild.getChildSObject());
                String lab = ((sObject)Type.forName(relatedObject).newInstance()).getSObjectType().getDescribe().getLabel();
                if(!labelsMap.containsKey(lab)){
                    labelsMap.put(lab,true);
                    labels.add( lab );
                }
                childRelationshipsMap.put(((sObject)Type.forName(relatedObject).newInstance()).getSObjectType().getDescribe().getLabel(), thisChild);
            }
        }

        labels.sort();
        for(String s : labels){
            Map<String,String> aux = new Map<String,String>();
            if(childRelationshipsMap.get(s).getRelationshipName() != null){
                aux.put('label', s);
                aux.put('name', String.valueOf(childRelationshipsMap.get(s).getChildSObject()));
                aux.put('relationshipName', String.valueOf(childRelationshipsMap.get(s).getRelationshipName()));
            }
            lista.add( aux );
        }
		return lista;
    }

    @AuraEnabled(cacheable=true)
    public static List<SObject> getWiredRecords(String fields, String objectName, String dataFilters, String orderBy, String recordsPerPage, String offset) {

        Schema.DescribeSObjectResult objectDescribe = ((sObject)Type.forName(objectName).newInstance()).getSObjectType().getDescribe();

        Set<String> picklistTypes = new Set<String>{'PICKLIST','MULTIPICKLIST'};
        List<String> fieldset = new List<String>();

        List<String> listFields = fields != null ? fields.deleteWhitespace().split(',') : new List<String>();

        Map<String,Schema.SObjectField> fieldMap = objectDescribe.fields.getMap();
        for(String fieldName: listFields){
            Schema.DescribeFieldResult fieldDescribe = fieldMap?.get(fieldName)?.getDescribe();
            if (fieldDescribe != null) {
                if(fieldMap.containskey(fieldName) && picklistTypes.contains(fieldDescribe.getType().name())){
                    fieldset.add('toLabel(' + fieldName + ') '+fieldName.toLowerCase()+'_label');
                } else if(fieldMap.containskey(fieldName) && fieldDescribe?.getType().name().tolowercase() == 'REFERENCE') {
                    Schema.DescribeFieldResult dfr = fieldDescribe;
                    String relatedObjNameField = getNameField( dfr.getReferenceTo()[0].getDescribe() );
                    if (String.isNotBlank(relatedObjNameField)) {
                        fieldset.add(dfr.getRelationshipName() + '.' + relatedObjNameField );
                    }
                }
            }
            fieldset.add(fieldName);
        }

        return queryPickListRecords(new List<String>(new Set<String>(fieldset)), fields, objectName, dataFilters, orderBy, recordsPerPage, offset);
    }

    public static List<SObject> queryPickListRecords(List<String> fieldset, String fields, String objectName, String dataFilters, String orderBy, String recordsPerPage, String offset) {
        List<SObject> result = new List<SObject>();

        if (!fieldset.contains('id')&&!fieldset.contains('Id')) fieldset.add('Id');

        String query = 'SELECT ';
        if (fields != '') {
            query += String.join(fieldset, ',');
        }
        query += ' FROM ' + objectName;
        query += ' WHERE ' + getWhereCondition(dataFilters, objectName);

        String lastModifiedDateField = SObjectUtils.getFieldNameLike(objectName, 'LastModifiedDate');

        String defaultOrderBy = '';
        if (String.isNotBlank(lastModifiedDateField)) {
            defaultOrderBy = lastModifiedDateField + ' DESC ';
        }

        // ORDER BY
        if (orderBy == null && String.isNotBlank(defaultOrderBy)){
            orderBy = defaultOrderBy;
        }

        if (String.isNotBlank(orderBy)) {
            query += ' ORDER BY '+ orderBy;
        }

        // LIMIT & OFFSET
        if (recordsPerPage != null) {
            query += ' LIMIT ' + recordsPerPage;
        }

        if ( offset != null ){
            query += ' OFFSET ' + offset;
        }

        result = Database.query(query);

        return result;
    }

    public static String getWhereCondition(String filterJson, String objectName) {
        Map<String, Schema.SObjectField> objectFields = ((sObject)Type.forName(objectName).newInstance()).getSObjectType().getDescribe().fields.getMap();

        String whereCondition = '';
        List<String> whereConditions = new List<String>();

        if (String.isNotBlank(filterJson) && filterJson != null ) {
            try {
                Map<String,Object> filter = (Map<String, Object>) JSON.deserializeUntyped( filterJson);
                for ( String k :filter.keySet() ) {
                    String value = string.valueOf(filter.get(k));
                    if (value == null || value == 'null') {
                        whereConditions.add(String.escapeSingleQuotes(k) + ' = null');
                    } else if(value.toLowerCase() == '!null') {
                        whereConditions.add(String.escapeSingleQuotes(k) + ' != null');
                    } else {
                        if(value.startsWith('BOOLEAN:')){
                            whereConditions.add(String.escapeSingleQuotes(k) + ' = ' +  String.escapeSingleQuotes(value.removeStart('BOOLEAN:')));
                        } else if(value.startsWith('LIKE:')){
                                if (objectName.toLowerCase() == 'fieloplt__member__c' && String.escapeSingleQuotes(k).toLowerCase() == 'name') {
                                    whereConditions.add('(' + String.escapeSingleQuotes(k) + ' LIKE \'%' +  String.escapeSingleQuotes(value.removeStart('LIKE:')) + '%\'' +
                                    ' OR FieloPLT__Email__c LIKE \'%' +  String.escapeSingleQuotes(value.removeStart('LIKE:')) + '%\') ');
                                } else {
                                    whereConditions.add(String.escapeSingleQuotes(k) + ' LIKE \'%' +  String.escapeSingleQuotes(value.removeStart('LIKE:')) + '%\'');
                                }
                        } else if ( value.startsWith('!') ) {
                            if ( value.startsWith('!IN:') ) {
                                string value2 = value.removeStart('!IN:');
                                List<String> ids = new List<String>();

                                for(String str: value2.split(',')){
                                    string strc = '\'' + str  + '\'';
                                    ids.add(strc);
                                }
                                whereConditions.add(String.escapeSingleQuotes(k) + ' NOT IN ' + ids);
                            } else {
                                whereConditions.add(String.escapeSingleQuotes(k) + ' <> \'' +  String.escapeSingleQuotes(value.substring(1)) + '\'');
                            }
                        } else if ( value.startsWith('IN:') ) {
                                string value2 = value.removeStart('IN:');
                                List<String> ids = new List<String>();

                                for(String str: value2.split(',')){
                                    string strc = '\'' + str  + '\'';
                                    ids.add(strc);
                                }
                                whereConditions.add(String.escapeSingleQuotes(k) + ' IN ' + ids);
                        } else if ( value.startsWith('FROM:') ) {
                            value = value.removeStart('FROM:');

                            if (objectFields.get(k).getDescribe().getSOAPType().name().tolowercase() == 'double') {
                                List<String> numbers = new List<String>();

                                if (value.contains('TO:')) {
                                    numbers = value.split('TO:');
                                } else {
                                    numbers.add(value);
                                }

                                for (Integer i = 0; i < numbers.size(); i++) {
                                    whereConditions.add( String.escapeSingleQuotes(k) + (i == 0 ? ' >= ' : ' <= ') + numbers[i]);
                                }

                            } else {
                                Date tempDate = Date.today();
                                DateTime tempDateTime = DateTime.newInstance(0);
                                List<String> dates = new List<String>();

                                if (value.contains('TO:')) {
                                    dates = value.split('TO:');
                                } else {
                                    dates.add(value);
                                }

                                for (Integer i = 0; i < dates.size(); i++) {
                                    tempDate = Date.valueOf(dates[i]);
                                    tempDateTime = DateTime.newInstance(tempDate.year(), tempDate.month(), tempDate.day());

                                    whereConditions.add(
                                        String.escapeSingleQuotes(k) +
                                        (i == 0 ? ' >= ' : ' <= ') +
                                        (objectFields.get(k).getDescribe().getType().name().tolowercase() == 'datetime' ?
                                            tempDateTime.format('yyyy-MM-dd\'T00:00:00Z\''):
                                            tempDateTime.format('yyyy-MM-dd'))
                                    );
                                }
                            }
                        } else if ( value.startsWith('TO:') ) {
                            Date tempDate = Date.valueOf(value.removeStart('TO:'));
                            DateTime tempDateTime = DateTime.newInstance(tempDate.year(), tempDate.month(), tempDate.day());

                            whereConditions.add(String.escapeSingleQuotes(k) + ' <= ' + tempDateTime.format('yyyy-MM-dd\'T00:00:00Z\''));
                        } else if ( objectName.tolowercase() == 'FieloPLT__Reward__c' && k.tolowercase() == 'fieloplt__program__c'){
                            whereConditions.add('( ' +
                                String.escapeSingleQuotes(k) + ' = \'' +  String.escapeSingleQuotes(value) + '\' OR ' +
                                String.escapeSingleQuotes(k) + ' = null ' +
                                ')'
                            );
                        } else {
                            whereConditions.add(String.escapeSingleQuotes(k) + ' = \'' +  String.escapeSingleQuotes(value) + '\'');
                        }
                    }
                }
            } catch( JSONException e ) {
                system.debug(LoggingLevel.ERROR, 'INVALID JSON ' + filterJson );
            }
        }
        return String.join(whereConditions, ' AND ');
    }

    public class CriteriaWrapper{
        public Boolean isCrossField;
        public Boolean isMasterDetail;
        public Boolean isUsingCriterionGroup;
        public Map<String,Set<String>> fieldsByObject;
        public Map<String,String> pointLookupByObject;
    }
}