public class SObjectUtils {

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

}