@isTest
public class TestErrorService {

    @isTest
    static void insertError() {
        try{
            throw new FieloPLT.FieloException('This is an error');
        } catch(Exception e) {
            ErrorService.insertError(e);
        }
        List<FieloPLT__ErrorLog__c> errors = [SELECT FieloPLT__Type__c, FieloPLT__Message__c FROM FieloPLT__ErrorLog__c];

        System.assertEquals('FieloPLT.FieloException', errors.get(0).FieloPLT__Type__c);
        System.assertEquals('This is an error', errors.get(0).FieloPLT__Message__c);
    }

    @isTest
    static void insertDMLError() {
        try{
            insert new FieloPLT__Member__c();
        } catch(DmlException e) {
            ErrorService.insertError(e);
        }
        List<FieloPLT__ErrorLog__c> errors = [SELECT FieloPLT__Type__c FROM FieloPLT__ErrorLog__c];

        System.assertEquals('System.DmlException', errors.get(0).FieloPLT__Type__c);
    }

    @isTest
    static void insertErrors() {
        Test.startTest();
        Database.SaveResult result = Database.insert(new FieloPLT__Member__c(), false);
        if (!result.isSuccess()) {
            ErrorService.insertErrors(result.getErrors());
        }
        List<FieloPLT__ErrorLog__c> errors = [SELECT FieloPLT__Type__c FROM FieloPLT__ErrorLog__c];

        System.assertEquals('Database.Error: FIELD_CUSTOM_VALIDATION_EXCEPTION', errors.get(0).FieloPLT__Type__c);
    }
}
