public class SObjectUtils {

    private static Map<sObjectType, DescribeSObjectResult> describeByToken;
    private static Map<String, sObjectType> tokenByString;

    /**
     * @description Method return if a field path exists in a SObjectType
     * @param token: token for the object
     * @param fieldPath: full fieldpath
     * @return  Boolean
     */
    public static boolean checkObjectHasField(sObjectType token, String fieldPathString) {
        Schema.DescribeSObjectResult objDescribe = SObjectUtils.getDescribeInstance(token);
        List<String> fieldPath = fieldPathString.trim().replaceAll('\\s','').toLowerCase().split('\\.');
        String fieldName = fieldPath.remove(0);

        if (fieldPath.isEmpty()) {
            return objDescribe.fields.getMap().containsKey(fieldName);
        } else {
            fieldName += !fieldPath.isEmpty() && !fieldName.endsWith('__r') && !fieldName.endsWith('id') ? 'id' : '';
            fieldName = fieldName.endsWith('__r') ? fieldName.removeEnd('__r') + '__c' : fieldName; // Changed replace to removeEnd + '__c' because it was changing FieloPLT__Redemption__r to FieloPLT__Cedemption__c
            Boolean hasField = false;

            if (objDescribe.fields.getMap().containsKey(fieldName)) {
                for(sObjectType refToSObjectType : objDescribe.fields.getMap().get(fieldName).getDescribe().getReferenceTo()) {
                    hasField = hasField || checkObjectHasField(refToSObjectType, String.join(fieldPath, '.'));
                    if (hasField) {
                        return true;
                    }
                }
            }
            return false;
        }
    }

    /**
     * @description Method return if a field path exists in a SObjectType
     * @param objectApiName: objectApiName for the object
     * @param fieldPath: full fieldpath
     * @return  Boolean
     */
    public static boolean checkObjectHasField(String objectApiName, String fieldPathString) {
        return checkObjectHasField(SObjectUtils.getSObjectTypeInstance(objectApiName), fieldPathString);
    }

    /**
     * @description Method return the type of a field in a SObjectType
     * @param token: token for the object
     * @param fieldPath: full fieldpath
     * @return  String: the fieldType
     */
    public static string getObjectFieldType(sObjectType token, String fieldPathString) {
        Schema.DescribeSObjectResult objDescribe = SObjectUtils.getDescribeInstance(token);
        List<String> fieldPath = fieldPathString.trim().replaceAll('\\s','').toLowerCase().split('\\.');
        String fieldName = fieldPath.remove(0);

        if (fieldPath.isEmpty()) {
            if (objDescribe.fields.getMap().containsKey(fieldName)) {
                return objDescribe.fields.getMap().get(fieldName).getDescribe().getType().name();
            } else {
                return null;
            }
        } else {
            fieldName += !fieldPath.isEmpty() && !fieldName.endsWith('__r') && !fieldName.endsWith('id') ? 'id' : '';
            fieldName = fieldName.endsWith('__r') ? fieldName.removeEnd('__r') + '__c' : fieldName; // Changed replace to removeEnd + '__c' because it was changing FieloPLT__Redemption__r to FieloPLT__Cedemption__c
            Boolean hasField = false;
            for(sObjectType refToSObjectType : objDescribe.fields.getMap().get(fieldName).getDescribe().getReferenceTo()) {
                hasField = hasField || checkObjectHasField(refToSObjectType, String.join(fieldPath, '.'));
                if (hasField) {
                    return getObjectFieldType(refToSObjectType, String.join(fieldPath, '.'));
                }
            }
            return null;
        }
    }

    public static Object getFieldValue(sObject record, String apiName) {
        Object value = null;
        if (apiName.contains('.')) {
            List<String> objectNameAndField = apiName.split('\\.');
            Boolean hasToLabel = apiName.contains('tolabel(') ? true : false;
            SObject currentObject = record;
            for(Integer i=0; i < objectNameAndField.size(); i++) {
                if (currentObject == null) break;
                if (i == objectNameAndField.size() - 1) {
                    String field = hasToLabel ? objectNameAndField[i].substringAfterLast(')').trim() : objectNameAndField[i];
                    value = currentObject.get(field);
                } else {
                    String objName = hasToLabel ? objectNameAndField[i].removeStart('tolabel(') : objectNameAndField[i];
                    currentObject = currentObject.getSObject(objName);
                }
            }
        } else {
            if(apiName.contains('tolabel(')){
                //Get only the alias
                apiName = apiName.substringAfterLast(')').trim();
            }
            value = record.get(apiName);
        }
        return value;
    }

    public static DescribeSObjectResult getDescribeInstance(String objectName) {
        return getDescribeInstance(getSObjectTypeInstance(objectName));
    }

    public static DescribeSObjectResult getDescribeInstance(sObjectType token) {
        if (describeByToken == null) {
            describeByToken = new Map<sObjectType, DescribeSObjectResult>{
                token => token.getDescribe()
            };
        } else if (!describeByToken.containsKey(token)) {
            describeByToken.put(token, token.getDescribe());
        }
        return describeByToken.get(token);
    }

    public static sObjectType getSObjectTypeInstance(String objectName) {
        if (tokenByString == null) {
            tokenByString = new Map<String, sObjectType>{
                objectName => Schema.describeSObjects(new List<String>{objectName}).get(0).getSObjectType()
            };
        } else if (!tokenByString.containsKey(objectName)) {
            tokenByString.put(objectName, Schema.describeSObjects(new List<String>{objectName}).get(0).getSObjectType());
        }
        return tokenByString.get(objectName);
    }

    public static Map<String,Map<String,sObjectType>> sobjectTypeByRelationshipByObject = new Map<String,Map<String,sObjectType>>();

    public static sObjectType getSObjectTypeFromChildRelationship(String objectName, String relationship) {
        sObjectType childSObjectType;

        if (sobjectTypeByRelationshipByObject?.get(objectName)?.get(relationship) != null) {
            childSObjectType = sobjectTypeByRelationshipByObject.get(objectName).get(relationship);
        } else {
            for (ChildRelationship cr : getDescribeInstance(getSObjectTypeInstance(objectName)).getChildRelationships()) {
                if (String.isNotBlank(cr.getRelationshipName()) && cr.getRelationshipName() == relationship) {
                    childSObjectType = cr.getChildSObject();
                    if (sobjectTypeByRelationshipByObject.containsKey(objectName)) {
                        sobjectTypeByRelationshipByObject.get(objectName).put(relationship, childSObjectType);
                    } else {
                        sobjectTypeByRelationshipByObject.put(objectName, new Map<String, sObjectType>{relationship => childSObjectType});
                    }
                    break;
                }
            }
        }
        return childSObjectType;
    }

    public static Map<Id, List<SObject>> getMapByFieldId(Schema.sObjectField fieldId, List<SObject> records) {

        Map<Id, List<SObject>> recordsMap = new Map<Id, List<SObject>>();
        for (Sobject record : records) {
            Id key = (Id) record.get(fieldId);
            if (recordsMap.containsKey(key)) {
                recordsMap.get(key).add(record);
            } else {
                recordsMap.put(key, new List<SObject>{record});
            }
        }

        return recordsMap;
    }

    private static Set<String> fieldsToSkip = new Set<String>{'LastModifiedById', 'LastModifiedDate', 'SystemModstamp'};

    public static Boolean isChanged(SObject newRecord, SObject oldRecord) {
        return isChanged(newRecord, oldRecord, newRecord.getPopulatedFieldsAsMap().keySet());
    }

    public static Boolean isChanged(SObject newRecord, SObject oldRecord, Set<String> fields) {

        for (String field : fields) {
            if (fieldsToSkip.contains(field)) continue;
            if (newRecord.get(field) != oldRecord.get(field)) return true;
        }

        return false;
    }

    public static Object getFirstNonNullValue(SObject record, List<String> fields) {
        for (String field : fields) {
            Object fieldValue = SObjectUtils.getFieldValue(record, field);
            if (fieldValue != null) return fieldValue;
        }
        return null;
    }

    public static boolean isExternalField(String objectName, String fieldPathString) {
        if (objectName.endsWith('__x')) return true;

        return isExternalField(SObjectUtils.getSObjectTypeInstance(objectName), fieldPathString);
    }

    public static boolean isExternalField(SObjectType objectToken, String fieldPathString) {
        Schema.DescribeSObjectResult objDescribe = SObjectUtils.getDescribeInstance(objectToken);
        List<String> fieldPath = fieldPathString.trim().replaceAll('\\s','').toLowerCase().split('\\.');
        String fieldName = fieldPath.remove(0);

        if (objDescribe.getName().endsWith('__x')) return true;

        if (fieldPath.isEmpty()) {
            return false;
        } else {
            fieldName += !fieldPath.isEmpty() && !fieldName.endsWith('__r') && !fieldName.endsWith('id') ? 'id' : '';
            fieldName = fieldName.endsWith('__r') ? fieldName.removeEnd('__r') + '__c' : fieldName;
            Boolean isExternal = false;
            for(sObjectType refToSObjectType : objDescribe.fields.getMap().get(fieldName).getDescribe().getReferenceTo()) {
                isExternal = refToSObjectType.getDescribe().getName().endsWith('__x') || isExternalField(refToSObjectType, String.join(fieldPath, '.'));
                if (isExternal) {
                    return true;
                }
            }
            return false;
        }
    }

    public static void assign(SObject target, SObject source, Set<String> fieldsToOverride) {
        fieldsToOverride = fieldsToLowerCase(fieldsToOverride);
        if (target != null && source != null){
            if (target.getSObjectType() != source.getSObjectType()) throw new FieloPLT.FieloException('Incompatible SObject types');

            for (String field : source.getPopulatedFieldsAsMap().keySet()) {
                field = field.toLowerCase();
                if(fieldsToOverride != null && fieldsToOverride.contains(field)){
                    try {
                        if (field.contains('__r')) {
                            List<String> fieldPath = field.split('\\.');
                            target.putSObject(fieldPath.get(0), source.getSObject(fieldPath.get(0)));
                        } else {
                            target.put(field, source.get(field));
                        }
                    } catch(Exception e) {
                        System.debug(logginglevel.ERROR, e.getMessage());
                    }
                }
            }
        }
    }

    public static void assign(SObject target, SObject source) {

        if (target != null && source != null){
            if (target.getSObjectType() != source.getSObjectType()) throw new FieloPLT.FieloException('Incompatible SObject types');

            for (String field : source.getPopulatedFieldsAsMap().keySet()) {
                try {
                    if (field.contains('__r')) {
                        List<String> fieldPath = field.split('\\.');
                        target.putSObject(fieldPath.get(0), source.getSObject(fieldPath.get(0)));
                    } else {
                        target.put(field, source.get(field));
                    }
                } catch(Exception e) {
                    System.debug(logginglevel.ERROR, e.getMessage());
                }
            }
        }
    }

    public static void bulkAssign(List<SObject> targetRecords, Map<Id,SObject> sourceRecordsMap, Set<String> fieldsToOverride){
        for(Sobject record : targetRecords){
            if (record == null) continue;
            if(fieldsToOverride != null && !fieldsToOverride.isEmpty()){
                assign(record, sourceRecordsMap?.get(record?.Id),fieldsToOverride);
            }else{
                assign(record, sourceRecordsMap?.get(record?.Id));
            }
        }
    }

    public static Map<String,SObject> getMapByField(String externalIdField, List<SObject> records) {
        Map<String,SObject> recordMap = new Map<String,SObject>();

        for (SObject record : records) recordMap.put(String.valueOf(record.get(externalIdField)), record);

        return recordMap;
    }

    public static Map<Object,SObject> getMapByAnyTypeField(String field, List<SObject> records) {
        Map<Object,SObject> recordMap = new Map<Object,SObject>();

        for (SObject record : records) recordMap.put(record.get(field), record);

        return recordMap;
    }

    public static String getDatetimeForQuery(Datetime datetimeValue) {
        return String.format('{0}T{1}Z', new List<String>{datetimeValue.formatGMT('yyyy-MM-dd'),datetimeValue.formatGMT('HH:mm:dd')});
    }

    public static List<String> getAllFields(SObjectType objectToken) {
        return new List<String>(objectToken.getDescribe().fields.getMap().keySet());
    }

    public static string getNameField(String objectName) {
        return getNameField(SObjectUtils.getSObjectTypeInstance(objectName));
    }

    public static string getNameField(sObjectType objectToken) {
        return getNameField(SObjectUtils.getDescribeInstance(objectToken));
    }

    public static string getNameField(DescribeSObjectResult objectDescribe) {
        for(Schema.SObjectField field : objectDescribe.fields.getMap().values()) {
            if (field.getDescribe().isNameField()) {
                return field.getDescribe().getName();
            }
        }
        return null;
    }

    public static Map<String, Schema.ChildRelationship> getChildRelationships(String objectName) {
        return getChildRelationships(getSObjectTypeInstance(objectName));
    }

    public static Map<String, Schema.ChildRelationship> getChildRelationships(sObjectType objectToken) {
        return getChildRelationships(getDescribeInstance(objectToken));
    }

    public static Map<String, Schema.ChildRelationship> getChildRelationships(DescribeSObjectResult objectDescribe) {
        Map<String,ChildRelationship> childRelationships = new Map<String,ChildRelationship>();
        for (ChildRelationship cr : objectDescribe.getChildRelationships()) {
            childRelationships.put(cr.getRelationshipName(), cr);
        }
        return childRelationships;
    }

    public static DescribeFieldResult getFieldDescribe(String objectName, String fieldPathString) {
        return getFieldDescribe(getSObjectTypeInstance(objectName), fieldPathString);
    }

    public static DescribeFieldResult getFieldDescribe(SObjectType objectToken, String fieldPathString) {
        return getFieldDescribe(getDescribeInstance(objectToken), fieldPathString);
    }

    public static DescribeFieldResult getFieldDescribe(DescribeSObjectResult objDescribe, String fieldPathString) {
        List<String> fieldPath = fieldPathString.trim().replaceAll('\\s','').toLowerCase().split('\\.');
        String fieldName = fieldPath.remove(0);

        if (fieldPath.isEmpty()) {
            return objDescribe.fields.getMap().get(fieldName).getDescribe();
        } else {
            fieldName += !fieldPath.isEmpty() && !fieldName.endsWith('__r') && !fieldName.endsWith('id') ? 'id' : '';
            fieldName = fieldName.endsWith('__r') ? fieldName.removeEnd('__r') + '__c' : fieldName;
            Boolean isExternal = false;
            for(sObjectType refToSObjectType : objDescribe.fields.getMap().get(fieldName).getDescribe().getReferenceTo()) {
                return getFieldDescribe(refToSObjectType, String.join(fieldPath, '.'));
            }
            return null;
        }
    }

    public static List<Map<String,Object>> denormalizeRecords(List<SObject> records) {
        List<Map<String,Object>> denormalizedRecords = new List<Map<String,Object>>();
        Map<String,Object> fieldValues;

        if (records == null || records?.isEmpty() == true) return denormalizedRecords;

        List<SObject> recordsToDenormalize = new List<SObject>(records);

        List<String> path = new List<String>();
        String pathStr = '';
        SObject record = recordsToDenormalize.remove(0);

        List<SObject> recordsStack = new List<SObject>();
        Boolean isLookup = false;
        Boolean isNewRecord = true;
        Map<String,Set<String>> fieldsByPath = new Map<String,Set<String>>();

        while(record != null) {

            if (!isLookup && isNewRecord) {
                isNewRecord = false;
                fieldValues = new Map<String,Object>();
            }
            if (!fieldsByPath.containsKey(pathStr)) {
                fieldsByPath.put(pathStr, new Set<String>(record.getPopulatedFieldsAsMap().keySet()));
            }
            for (String field : new Set<String>(fieldsByPath.get(pathStr))) {
                fieldsByPath.get(pathStr).remove(field);
                if (field.endsWith('__r')) {
                    recordsStack.add(record);
                    record = record.getSObject(field);
                    path.add(field);
                    pathStr = String.join(path, '.');
                    isLookup = true;
                    break;
                } else {
                    if (path.isEmpty()) {
                        fieldValues.put(field, record.get(field));
                    } else {
                        fieldValues.put( pathStr + '.' + field, record.get(field) );
                    }
                }
            }

            if (isLookup && fieldsByPath.get(pathStr)?.isEmpty() == true) {
                isLookup = false;
            }

            if (isLookup) {
                continue;
            } else {
                if (recordsStack.isEmpty() == false) {
                    record = recordsStack.remove(recordsStack.size()-1);
                    path.remove(path.size()-1);
                    pathStr = String.join(path, '.');
                } else if (recordsToDenormalize.isEmpty() == false) {
                    denormalizedRecords.add(fieldValues);
                    record = recordsToDenormalize.remove(0);
                    fieldsByPath = new Map<String,Set<String>>();
                    isNewRecord = true;
                } else {
                    denormalizedRecords.add(fieldValues);
                    record = null;
                }
            }
        }

        return denormalizedRecords;
    }

    public static void addFields(SObject sobj, Set<String> fields, Map<String, Object> recordMap, Set<String> exceptionfieldsInput){
        Set<String> exceptionfields = (exceptionfieldsInput == null)? new Set<String>(): exceptionfieldsInput;

        if(fields != null && !fields.isEmpty()){
            for(String f :fields){
                String field = f.toLowerCase();
                if(!exceptionfields.contains(field)) {
                    if(field.contains('__r.')){
                        List<String> fieldSplitted = field.split('\\.');
                        Boolean hasToLabel = false;
                        if(field.contains('tolabel(')){
                            hasToLabel = true;
                            //Get only the alias
                            field = field.substringAfterLast(')');
                        }
                        if(fieldSplitted.size() == 2){
                            String objName = hasToLabel ? fieldSplitted[0].removeStart('tolabel(') : fieldSplitted[0];
                            SObject obj = sobj.getSObject(objName);
                            //Get the alias
                            String fieldName = hasToLabel ? fieldSplitted[1].substringAfterLast(')') : fieldSplitted[1];
                            if(obj!= null && obj.get(fieldName) != null){
                                recordMap.put(field, String.valueOf(obj.get(fieldName)));
                            }
                        }else{
                            Integer index = 0;
                            String fieldName = fieldSplitted[index];
                            fieldName = hasToLabel ? fieldName.removeStart('tolabel(') : fieldName;
                            SObject relatedRecord;
                            for(; index < fieldSplitted.size() -1 ; index++){
                                if(relatedRecord == null){
                                    relatedRecord = sobj.getSObject(fieldName);
                                }else{
                                    relatedRecord = relatedRecord.getSObject(fieldName);
                                }
                                fieldName = fieldSplitted[index+1];
                            }
                            fieldName = hasToLabel ? fieldName.substringAfterLast(')') : fieldName;
                            if(relatedRecord != null && relatedRecord.get(fieldName) != null){
                                recordMap.put(field, String.valueOf(relatedRecord.get(fieldName)));
                            }
                        }
                    }else{
                        if(field.contains('tolabel(')){
                            //Get only the alias
                            field = field.substringAfterLast(')');
                        }
                        if(sobj?.get(field) != null) {
                            recordMap.put(field, sobj?.get(field));
                        }
                    }
                }
            }
        }
    }

	public static map<string,DescribeFieldResult> getFieldsFromRelationshipType(String objectName, String relationshipType) {
        map<string, Schema.SObjectField> fieldMap = getDescribeInstance(getSObjectTypeInstance(objectName)).fields.getMap();
        map<string,DescribeFieldResult> mapFieldsType = new map<string,DescribeFieldResult> ();

        for(String fiedName : fieldMap.keySet()){

            Schema.DescribeFieldResult field = fieldMap.get(fiedName).getDescribe();

            List <Schema.sObjectType> sObjectReference = field.getReferenceTo();
            if(sObjectReference?.size() > 0 && relationshipType == sObjectReference[0].getDescribe().getName())
            {
                mapFieldsType.put(field.getName(), field);
            }

        }
        return mapFieldsType;
    }

    public static List<SObjectField> getLookupsToSObjectToken(String childSObject, String referenceTo) {
        return getLookupsToSObjectToken(getSObjectTypeInstance(childSObject), getSObjectTypeInstance(referenceTo));
    }

    public static List<SObjectField> getLookupsToSObjectToken(String childSObject, SObjectType referenceToToken) {
        return getLookupsToSObjectToken(getSObjectTypeInstance(childSObject), referenceToToken);
    }

    public static List<SObjectField> getLookupsToSObjectToken(SObjectType childSObjectToken, SObjectType referenceToToken) {
        return getLookupsToSObjectToken(getDescribeInstance(childSObjectToken), referenceToToken);
    }

    public static List<SObjectField> getLookupsToSObjectToken(DescribeSObjectResult childObjectDescribe, SObjectType referenceToToken) {
        List<SObjectField> fieldTokens = new List<SObjectField>();

        for (SObjectField fieldToken : childObjectDescribe.fields.getMap().values()) {
            for(SObjectType referenceTo : fieldToken.getDescribe().getReferenceTo()) {
                if (referenceTo == referenceToToken) {
                    fieldTokens.add(fieldToken);
                }
            }
        }

        return fieldTokens;
    }

    public static List<String> getLookupsListToSObjectToken(String childSObject, String referenceTo) {
        return getLookupsListToSObjectToken(getSObjectTypeInstance(childSObject), getSObjectTypeInstance(referenceTo));
    }

    public static List<String> getLookupsListToSObjectToken(String childSObject, SObjectType referenceToToken) {
        return getLookupsListToSObjectToken(getSObjectTypeInstance(childSObject), referenceToToken);
    }

    public static List<String> getLookupsListToSObjectToken(SObjectType childSObjectToken, SObjectType referenceToToken) {
        return getLookupsListToSObjectToken(getDescribeInstance(childSObjectToken), referenceToToken);
    }

    public static List<String> getLookupsListToSObjectToken(DescribeSObjectResult childObjectDescribe, SObjectType referenceToToken) {
        List<String> fieldNames = new List<String>();

        for (SObjectField fieldToken : childObjectDescribe.fields.getMap().values()) {
            for(SObjectType referenceTo : fieldToken.getDescribe().getReferenceTo()) {
                if (referenceTo == referenceToToken) {
                    fieldNames.add(fieldToken.getDescribe().getName());
                }
            }
        }

        return fieldNames;
    }

    public static string getExternalIdField(String sobjectName) {
        if (sobjectName.toLowerCase() == 'fieloplt__member__c') {
            return 'FieloPLT__ExternalId__c';
        } else if (sobjectName.endsWith('__x')) {
            return 'ExternalId';
        } else {
            return getExternalIdField(getSObjectTypeInstance(sobjectName));
        }
    }

    public static string getExternalIdField(SObjectType sobjectToken) {
        if (sobjectToken == fieloplt__member__c.sobjecttype) {
            return 'FieloPLT__ExternalId__c';
        } else {
            return getExternalIdField(getDescribeInstance(sobjectToken));
        }
    }

    public static string getExternalIdField(DescribeSObjectResult sobjectDescribe) {
        if (sobjectDescribe.getName().toLowerCase() == 'fieloplt__member__c') {
            return 'FieloPLT__ExternalId__c';
        } else if (sobjectDescribe.getName().endsWith('__x')) {
            return 'ExternalId';
        } else {
            for (SObjectField fieldToken : sobjectDescribe.fields.getMap().values()) {
                if (fieldToken.getDescribe().isExternalID())
                    return fieldToken.getDescribe().getName();
            }
        }
        return null;
    }

    public static Set<String> fieldsToLowerCase(Set<String> fields){
        if (fields == null) {
            return new Set<String>();
        } else {
            return new Set<String>(String.join(new List<String>(fields),',').toLowerCase().split(','));
        }
    }

    public static string getFieldNameLike(String objectName, String fieldNamePart) {
        return getFieldNameLike(getSObjectTypeInstance(objectName),fieldNamePart);
    }

    public static string getFieldNameLike(SObjectType objectToken, String fieldNamePart) {
        return getFieldNameLike(getDescribeInstance(objectToken),fieldNamePart);
    }

    public static string getFieldNameLike(DescribeSObjectResult objectDescribe, String fieldNamePart) {
        for (String fieldName : objectDescribe.fields.getMap().keySet()) {
            if (fieldName.toLowerCase().contains(fieldNamePart)) {
                return fieldName;
            }
        }
        return null;
    }

    // removes all spaces from names not between ()
    // it won't break sub queries
    public static final string EMPTY_SPACES_REGEXP = '\\s(?![^\\(]*\\))';

    public static set<String> deleteDuplicateFields(List<String> fields) {

        String query = String.join(fields, ',').toLowerCase().replaceAll('\\s*,\\s*',',');

        return new Set<String>(query.split(',(?![^\\(]*\\))'));
    }

    public static set<String> deleteDuplicateFields(Set<String> fields){
        return deleteDuplicateFields(new List<String>(fields));
    }
}