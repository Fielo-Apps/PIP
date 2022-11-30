public with sharing class SObjectSelector {

    public
    static final Set<String> PICKLIST_TYPES = new Set<String>{'PICKLIST','MULTIPICKLIST'};

    public static sObject getRecord(Id recordId) {
        List<SObject> records = getRecords(new Set<Id>{recordId}, false);
        return records.isEmpty() ?  null : records.get(0);
    }

    public static sObject getRecord(Id recordId, Boolean translatePicklists) {
        List<SObject> records = getRecords(new Set<Id>{recordId}, translatePicklists);
        return records.isEmpty() ?  null : records.get(0);
    }

    public static List<sObject> getRecords(List<Id> recordIds) {
        return getRecords(new Set<Id>(recordIds), false);
    }

    public static List<sObject> getRecords(Set<Id> recordIds) {
        return getRecords(recordIds, false);
    }

    public static List<sObject> getRecords(Set<Id> recordIds, Boolean translatePicklists) {
        SObjectType objectToken = new List<Id>(recordIds)?.get(0)?.getSobjectType();
        DescribeSobjectResult objectDescribe = objectToken.getDescribe();
        String objectName = objectDescribe.getName();
        Set<String> fieldSet;
        if (translatePicklists == true) {
            fieldSet = new Set<String>();
            Map<String,SObjectField> fieldsMap = objectDescribe.fields.getMap();
            for(String fieldName : fieldsMap.keyset()) {
                if (PICKLIST_TYPES.contains(fieldsMap.get(fieldName).getDescribe().getType().name())) {
                    fieldSet.add('toLabel('+fieldName+') '+fieldName);
                } else {
                    fieldSet.add(fieldName);
                }
            }
        } else {
           fieldSet = objectDescribe.fields.getMap().keyset();
        }

        return Database.query(
            'SELECT ' +
                String.join(new List<String>(fieldSet), ',') +
            ' FROM ' + objectName + ' WHERE Id IN :recordIds');
    }
}
