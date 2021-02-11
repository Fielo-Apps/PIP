public class SimulatorService {
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
        return new Set<String>(String.join(new List<String>(fields), ',').toLowerCase().replaceAll(EMPTY_SPACES_REGEXP,'').split(','));
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
                    if( objectName == 'FieloPLT__Member__c' && relatedObject == 'FieloPLT__LevelMember__c'){
                        labels.add( 'Rank Member' );
                    }
                    if( objectName == 'FieloPLT__Member__c' && relatedObject == 'FieloPLT__Member__c' && String.valueOf(thisChild.getField()) == 'FieloPLT__OrganizationAccount__c'){
                        if(context != 'Behavior'){
                            labels.add('Contributor');
                            childRelationshipsMap.put('Contributor', thisChild);
                            continue; //Avoid put the member label in the map below
                        }
                    }else if(objectName == 'FieloPLT__Member__c' && relatedObject == 'FieloPLT__Member__c' && String.valueOf(thisChild.getField()) == 'FieloPLT__MergedTo__c'){
                        //Do nothing, because a Merged or Pending Merge member can't be part of a Segment or be evaluated for the rule engine. So there is no sense to have this option
                        continue;
                    }

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
            if( s == 'Rank Member' ){
                aux.put('label', s);
                aux.put('name', 'FieloPLT__RankMember__c');
                aux.put('relationshipName', 'FieloPLT__RankMembers__r');
            } else {
                if(childRelationshipsMap.get(s).getRelationshipName() != null){
                    aux.put('label', s);
                    aux.put('name', String.valueOf(childRelationshipsMap.get(s).getChildSObject()));
                    aux.put('relationshipName', String.valueOf(childRelationshipsMap.get(s).getRelationshipName()));
                }
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
        for( Integer i = 0; i < listFields.size(); i++ ){
            if ( listFields.get(i) == 'RecordType') {
                listFields.remove(i);
                listFields.add('RecordTypeId');
            }
        }

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
        String query = 'SELECT Id ';
        if (fields != '') {
            query += ', ' + String.join(fieldset, ',');
        }
        query += ' FROM ' + objectName;
        query += getWhereCondition(dataFilters, objectName);

        // ORDER BY
        if (orderBy == null){
            orderBy = 'LastModifiedDate DESC';
        }
        query += ' ORDER BY '+ orderBy;

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
        if (String.isNotBlank(filterJson) && filterJson != null ) {
            try {
                Map<String,Object> filter = (Map<String, Object>) JSON.deserializeUntyped( filterJson);
                for ( String k :filter.keySet() ) {
                    String value = string.valueOf(filter.get(k));
                    if (value == null || value == 'null') {
                        whereCondition += ' AND ' + String.escapeSingleQuotes(k) + ' = null';
                    } else if(value.toLowerCase() == '!null') {
                        whereCondition += ' AND ' + String.escapeSingleQuotes(k) + ' != null';
                    } else {
                        if(value.startsWith('BOOLEAN:')){
                                whereCondition += ' AND ' + String.escapeSingleQuotes(k) + ' = ' +  String.escapeSingleQuotes(value.removeStart('BOOLEAN:'));
                        } else if(value.startsWith('LIKE:')){
                                if (objectName.toLowerCase() == 'fieloplt__member__c' && String.escapeSingleQuotes(k).toLowerCase() == 'name') {
                                    whereCondition += ' AND (' + String.escapeSingleQuotes(k) + ' LIKE \'%' +  String.escapeSingleQuotes(value.removeStart('LIKE:')) + '%\'' +
                                    ' OR FieloPLT__Email__c LIKE \'%' +  String.escapeSingleQuotes(value.removeStart('LIKE:')) + '%\') ';
                                } else {
                                    whereCondition += ' AND ' + String.escapeSingleQuotes(k) + ' LIKE \'%' +  String.escapeSingleQuotes(value.removeStart('LIKE:')) + '%\'';
                                }
                        } else if ( value.startsWith('!') ) {
                                whereCondition += ' AND ' + String.escapeSingleQuotes(k) + ' <> \'' +  String.escapeSingleQuotes(value.substring(1)) + '\'';
                        } else if ( value.startsWith('IN:') ) {
                                string value2 = value.removeStart('IN:');
                                List<String> ids = new List<String>();

                                for(String str: value2.split(',')){
                                    string strc = '\'' + str  + '\'';
                                    ids.add(strc);
                                }
                                whereCondition += ' AND '  + String.escapeSingleQuotes(k) + ' IN ' + ids;
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
                                    whereCondition += ' AND ' + String.escapeSingleQuotes(k);
                                    if (i == 0) {
                                        // FROM
                                        whereCondition += ' >= ';
                                    } else {
                                        // TO
                                        whereCondition += ' <= ';
                                    }
                                    whereCondition += numbers[i];
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

                                    whereCondition += ' AND ' + String.escapeSingleQuotes(k);
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
                                }
                            }
                        } else if ( value.startsWith('TO:') ) {
                            Date tempDate = Date.valueOf(value.removeStart('TO:'));
                            DateTime tempDateTime = DateTime.newInstance(tempDate.year(), tempDate.month(), tempDate.day());

                            whereCondition += ' AND '  + String.escapeSingleQuotes(k) + ' <= ' + tempDateTime.format('yyyy-MM-dd\'T00:00:00Z\'') ;
                        } else if ( objectName.tolowercase() == 'FieloPLT__Reward__c' && k.tolowercase() == 'fieloplt__program__c'){
                                whereCondition += ' AND ( ' +
                                    String.escapeSingleQuotes(k) + ' = \'' +  String.escapeSingleQuotes(value) + '\' OR ' +
                                    String.escapeSingleQuotes(k) + ' = null ' +
                                    ')';
                        } else {
                                whereCondition += ' AND ' + String.escapeSingleQuotes(k) + ' = \'' +  String.escapeSingleQuotes(value) + '\'';
                        }
                    }
                }
                if ( whereCondition != '') {
                    whereCondition = ' WHERE ' + whereCondition.substring(4);
                }
            } catch( JSONException e ) {
                system.debug(LoggingLevel.ERROR, 'INVALID JSON ' + filterJson );
            }
        }
        return whereCondition;
    }

    public class CriteriaWrapper{
        public Boolean isCrossField;
        public Boolean isMasterDetail;
        public Boolean isUsingCriterionGroup;
        public Map<String,Set<String>> fieldsByObject;
        public Map<String,String> pointLookupByObject;
    }
}
