@isTest
public class TestSObjectUtils {

    @isTest
    static void getLookupsToSObjectToken() {
        Set<String> fieldNames = new Set<String>();
        for(SObjectField fieldToken : SObjectUtils.getLookupsToSObjectToken('FieloPLT__Event__c','User')) {
            fieldNames.add(fieldToken.getDescribe().getName());
        }

        System.assert(fieldNames.contains('OwnerId'), 'OwnerId not found');
        System.assert(fieldNames.contains('CreatedById'), 'CreatedById not found');
        System.assert(fieldNames.contains('LastModifiedById'), 'LastModifiedById not found');
    }

    @isTest
    static void getLookupsToSObjectToken2() {
        Set<String> fieldNames = new Set<String>();
        for(SObjectField fieldToken : SObjectUtils.getLookupsToSObjectToken('FieloPLT__Event__c',User.sobjecttype)) {
            fieldNames.add(fieldToken.getDescribe().getName());
        }

        System.assert(fieldNames.contains('OwnerId'), 'OwnerId not found');
        System.assert(fieldNames.contains('CreatedById'), 'CreatedById not found');
        System.assert(fieldNames.contains('LastModifiedById'), 'LastModifiedById not found');
    }

    @isTest
    static void getLookupsToSObjectToken3() {
        Set<String> fieldNames = new Set<String>();
        for(SObjectField fieldToken : SObjectUtils.getLookupsToSObjectToken(FieloPLT__Event__c.sobjecttype,User.sobjecttype)) {
            fieldNames.add(fieldToken.getDescribe().getName());
        }

        System.assert(fieldNames.contains('OwnerId'), 'OwnerId not found');
        System.assert(fieldNames.contains('CreatedById'), 'CreatedById not found');
        System.assert(fieldNames.contains('LastModifiedById'), 'LastModifiedById not found');
    }

    @isTest
    static void getLookupsListToSObjectToken() {
        Set<String> fieldNames = new Set<String>(SObjectUtils.getLookupsListToSObjectToken('FieloPLT__Event__c','User'));

        System.assert(fieldNames.contains('OwnerId'), 'OwnerId not found');
        System.assert(fieldNames.contains('CreatedById'), 'CreatedById not found');
        System.assert(fieldNames.contains('LastModifiedById'), 'LastModifiedById not found');
    }

    @isTest
    static void getLookupsListToSObjectToken2() {
        Set<String> fieldNames = new Set<String>(SObjectUtils.getLookupsListToSObjectToken('FieloPLT__Event__c',User.sobjecttype));

        System.assert(fieldNames.contains('OwnerId'), 'OwnerId not found');
        System.assert(fieldNames.contains('CreatedById'), 'CreatedById not found');
        System.assert(fieldNames.contains('LastModifiedById'), 'LastModifiedById not found');
    }

    @isTest
    static void getLookupsListToSObjectToken3() {
        Set<String> fieldNames = new Set<String>(SObjectUtils.getLookupsListToSObjectToken(FieloPLT__Event__c.sobjecttype,User.sobjecttype));

        System.assert(fieldNames.contains('OwnerId'), 'OwnerId not found');
        System.assert(fieldNames.contains('CreatedById'), 'CreatedById not found');
        System.assert(fieldNames.contains('LastModifiedById'), 'LastModifiedById not found');
    }

    @isTest
    static void getDescribeInstance() {
        DescribeSObjectResult objectDescribeByString = SObjectUtils.getDescribeInstance('FieloPLT__Member__c');
        DescribeSObjectResult objectDescribeByToken = SObjectUtils.getDescribeInstance(fieloplt__Member__c.sobjecttype);

        System.assertEquals(objectDescribeByString.getName(),objectDescribeByToken.getName(),'Wrong object describe');
        System.assertEquals(objectDescribeByString.getKeyPrefix(),objectDescribeByToken.getKeyPrefix(),'Wrong object describe');
    }

    @isTest
    static void getNameField() {
        String nameByString = SObjectUtils.getNameField('FieloPLT__Member__c');
        String nameByToken = SObjectUtils.getNameField(FieloPLT__Member__c.sobjecttype);
        String nameByDescribe = SObjectUtils.getNameField(sobjecttype.FieloPLT__Member__c);

        System.assertEquals(nameByString, nameByToken, 'Wrong Name Field');
        System.assertEquals(nameByString, nameByDescribe, 'Wrong Name Field');
        System.assertEquals(nameByToken, nameByDescribe, 'Wrong Name Field');
    }

    @isTest
    static void getDatetimeForQuery() {
        Datetime specialDate = Datetime.newInstance(1986,8,13,4,50,0);

        String expectedDatetime = String.format('{0}T{1}Z', new List<String>{specialDate.formatGMT('yyyy-MM-dd'),specialDate.formatGMT('HH:mm:dd')});

        System.assertEquals(expectedDatetime, SObjectUtils.getDatetimeForQuery(specialDate), 'Wrong datetime');
    }
}
