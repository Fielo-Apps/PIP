global class BehaviorObjectsDatasource extends VisualEditor.DynamicPickList{

    global override VisualEditor.DataRow getDefaultValue(){
        List<FieloPLT__RuleTrigger__c> behaviors = [SELECT Id, Name, FieloPLT__Object__c FROM FieloPLT__RuleTrigger__c WHERE FieloPLT__Status__c = 'Active' AND FieloPLT__Object__c = 'FieloPLT__Event__c'];
        VisualEditor.DataRow defaultValue;
        if (!behaviors.isEmpty()) {
            defaultValue = new VisualEditor.DataRow(behaviors.get(0).Name, behaviors.get(0).FieloPLT__Object__c);
        } else {
            defaultValue = new VisualEditor.DataRow('FieloPLT__Event__c', 'FieloPLT__Event__c');
        }
        return defaultValue;
    }

    global override VisualEditor.DynamicPickListRows getValues() {
        List<FieloPLT__RuleTrigger__c> behaviors = [SELECT Id, Name, FieloPLT__Object__c FROM FieloPLT__RuleTrigger__c WHERE FieloPLT__Status__c = 'Active'];

        VisualEditor.DynamicPickListRows  myValues = new VisualEditor.DynamicPickListRows();
        if (!behaviors.isEmpty()) {
            for (FieloPLT__RuleTrigger__c b : behaviors) {
                myValues.addRow(new VisualEditor.DataRow(b.Name, b.FieloPLT__Object__c));
            }
        } else {
            myValues.addRow(new VisualEditor.DataRow('FieloPLT__Event__c', 'FieloPLT__Event__c'));
        }

        return myValues;
    }
}