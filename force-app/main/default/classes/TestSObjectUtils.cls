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

    @isTest
    static void checkObjectHasField() {
        System.assert(SObjectUtils.checkObjectHasField('FieloPLT__Rule__c','FieloPLT__Promotion__r.FieloPLT__Program__c'));

        System.assert(SObjectUtils.checkObjectHasField(FieloPLT__Rule__c.sobjecttype, 'FieloPLT__Promotion__r.FieloPLT__Program__c'));
    }

    @isTest
    static void getObjectFieldType() {
        System.assertEquals('STRING', SObjectUtils.getObjectFieldType(FieloPLT__Rule__c.sobjecttype, 'FieloPLT__Promotion__r.FieloPLT__Program__r.Name'), 'Wrong field type');
    }

    @isTest
    static void getSObjectTypeInstance() {
        System.assertEquals(FieloPLT__Member__c.sobjecttype, SObjectUtils.getSObjectTypeInstance('FieloPLT__Member__c'), 'Wrong sobject type');
    }

    @isTest
    static void getSObjectTypeFromChildRelationship() {
        System.assertEquals(FieloPLT__Transaction__c.sobjecttype, SObjectUtils.getSObjectTypeFromChildRelationship('FieloPLT__Member__c','FieloPLT__Transactions__r'), 'Wrong sobject type');
    }

    @istest
    static void getMapByFieldId() {
        FieloPLT__Program__c program = new FieloPLT__Program__c(
            Name = 'Program',
            FieloPLT__OnlineTransactionProcessing__c = true,
            FieloPLT__EnableIncentivesCalculator__c = true
        );

        insert program;

        List<FieloPLT__Member__c> members = new List<FieloPLT__Member__c>{
            new FieloPLT__Member__c(
                Name = 'Member A',
                FieloPLT__Email__c = ('Member A').deleteWhitespace() + Datetime.now().getTime() + '@fielo.com',
                FieloPLT__Program__c = program.Id,
                FieloPLT__Type__c = 'Individual Account'
            ),
            new FieloPLT__Member__c(
                Name = 'Member B',
                FieloPLT__Email__c = ('Member B').deleteWhitespace() + Datetime.now().getTime() + '@fielo.com',
                FieloPLT__Program__c = program.Id,
                FieloPLT__Type__c = 'Individual Account'
            )
        };

        insert members;

        Map<Id, List<SObject>> result = SObjectUtils.getMapByFieldId(FieloPLT__Member__c.FieloPLT__Program__c, members);
    }

    @istest
    static void isChanged() {
        FieloPLT__Program__c program = new FieloPLT__Program__c(
            Name = 'Program',
            FieloPLT__OnlineTransactionProcessing__c = true,
            FieloPLT__EnableIncentivesCalculator__c = true
        );

        insert program;

        FieloPLT__Member__c memberA = new FieloPLT__Member__c(
                Name = 'Member A',
                FieloPLT__Email__c = ('Member A').deleteWhitespace() + Datetime.now().getTime() + '@fielo.com',
                FieloPLT__Program__c = program.Id,
                FieloPLT__Type__c = 'Individual Account'
        );
        FieloPLT__Member__c memberb = new FieloPLT__Member__c(
            Name = 'Member B',
            FieloPLT__Email__c = ('Member B').deleteWhitespace() + Datetime.now().getTime() + '@fielo.com',
            FieloPLT__Program__c = program.Id,
            FieloPLT__Type__c = 'Individual Account'
        );
        insert new List<FieloPLT__Member__c>{memberA,memberB};

        System.assert(SObjectUtils.isChanged(memberA, memberB));

        System.assert(SObjectUtils.isChanged(memberA, memberB, new Set<String>{'Name'}));
    }

    @istest
    static void getFirstNonNullValue() {
        FieloPLT__Program__c program = new FieloPLT__Program__c(
            Name = 'Program',
            FieloPLT__OnlineTransactionProcessing__c = true,
            FieloPLT__EnableIncentivesCalculator__c = true
        );

        insert program;

        FieloPLT__Member__c memberA = new FieloPLT__Member__c(
                Name = 'Member A',
                FieloPLT__Email__c = ('Member A').deleteWhitespace() + Datetime.now().getTime() + '@fielo.com',
                FieloPLT__Program__c = program.Id,
                FieloPLT__Type__c = 'Individual Account'
        );
        FieloPLT__Member__c memberB = new FieloPLT__Member__c(
            Name = 'Member B',
            FieloPLT__Email__c = ('Member B').deleteWhitespace() + Datetime.now().getTime() + '@fielo.com',
            FieloPLT__Program__c = program.Id,
            FieloPLT__Type__c = 'Individual Account'
        );
        insert new List<FieloPLT__Member__c>{memberA,memberB};

        System.assertEquals(program.Id, SObjectUtils.getFirstNonNullValue(memberA, new List<String>{'FieloPLT__Program__c'}));
    }

    @istest
    static void isExternalField() {
        System.assert(!SObjectUtils.isExternalField('FieloPLT__Rule__c','FieloPLT__Promotion__r.FieloPLT__Program__c'));
        System.assert(!SObjectUtils.isExternalField(FieloPLT__Rule__c.sobjecttype,'FieloPLT__Promotion__r.FieloPLT__Program__c'));
    }

    @istest
    static void assign() {
        FieloPLT__Program__c program = new FieloPLT__Program__c(
            Name = 'Program',
            FieloPLT__OnlineTransactionProcessing__c = true,
            FieloPLT__EnableIncentivesCalculator__c = true
        );

        insert program;

        FieloPLT__Member__c memberA = new FieloPLT__Member__c(
                Name = 'Member A',
                FieloPLT__Email__c = ('Member A').deleteWhitespace() + Datetime.now().getTime() + '@fielo.com',
                FieloPLT__Program__c = program.Id,
                FieloPLT__Type__c = 'Individual Account'
        );
        FieloPLT__Member__c memberB = new FieloPLT__Member__c(
            Name = 'Member B',
            FieloPLT__Email__c = ('Member B').deleteWhitespace() + Datetime.now().getTime() + '@fielo.com',
            FieloPLT__Program__c = program.Id,
            FieloPLT__Type__c = 'Individual Account'
        );
        FieloPLT__Member__c memberC = new FieloPLT__Member__c(
            Name = 'Member C',
            FieloPLT__Email__c = ('Member C').deleteWhitespace() + Datetime.now().getTime() + '@fielo.com',
            FieloPLT__Program__c = program.Id,
            FieloPLT__Type__c = 'Individual Account'
        );
        insert new List<FieloPLT__Member__c>{memberA,memberB,memberC};

        FieloPLT__Member__c memberBKP = new FieloPLT__Member__c();

        SObjectUtils.assign(memberBKP, memberA);
        SObjectUtils.assign(memberA, memberB);
        SObjectUtils.assign(memberB, memberC, new Set<String>{'Name','FieloPLT__Email__c'});
        SObjectUtils.assign(memberC, memberBKP, new Set<String>{'Name','FieloPLT__Email__c'});

        System.assertEquals('Member B', memberA.Name);
        System.assertEquals('Member C', memberB.Name);
        System.assertEquals('Member A', memberC.Name);
    }

    @istest
    static void bulkAssign() {
        FieloPLT__Program__c program = new FieloPLT__Program__c(
            Name = 'Program',
            FieloPLT__OnlineTransactionProcessing__c = true,
            FieloPLT__EnableIncentivesCalculator__c = true
        );

        insert program;

        FieloPLT__Member__c memberA = new FieloPLT__Member__c(
                Name = 'Member A',
                FieloPLT__Email__c = ('Member A').deleteWhitespace() + Datetime.now().getTime() + '@fielo.com',
                FieloPLT__Program__c = program.Id,
                FieloPLT__Type__c = 'Individual Account'
        );
        FieloPLT__Member__c memberB = new FieloPLT__Member__c(
            Name = 'Member B',
            FieloPLT__Email__c = ('Member B').deleteWhitespace() + Datetime.now().getTime() + '@fielo.com',
            FieloPLT__Program__c = program.Id,
            FieloPLT__Type__c = 'Individual Account'
        );
        FieloPLT__Member__c memberC = new FieloPLT__Member__c(
            Name = 'Member C',
            FieloPLT__Email__c = ('Member C').deleteWhitespace() + Datetime.now().getTime() + '@fielo.com',
            FieloPLT__Program__c = program.Id,
            FieloPLT__Type__c = 'Individual Account'
        );
        List<FieloPLT__Member__c> members = new List<FieloPLT__Member__c>{memberA,memberB,memberC};
        insert members;

        Map<Id, FieloPLT__Member__c> membersBKPMap = new Map<Id, FieloPLT__Member__c>(members.deepClone(true, true, true));
        FieloPLT__Member__c memberBKP = new FieloPLT__Member__c();

        System.assertEquals('Member A', members.get(0).Name);
        System.assertEquals('Member B', members.get(1).Name);
        System.assertEquals('Member C', members.get(2).Name);

        SObjectUtils.assign(memberBKP, members.get(0));
        SObjectUtils.assign(members.get(0), members.get(1), new Set<String>{'Name','FieloPLT__Email__c','FieloPLT__Program__c','FieloPLT__Type__c'});
        SObjectUtils.assign(members.get(1), members.get(2), new Set<String>{'Name','FieloPLT__Email__c','FieloPLT__Program__c','FieloPLT__Type__c'});
        SObjectUtils.assign(members.get(2), memberBKP, new Set<String>{'Name','FieloPLT__Email__c','FieloPLT__Program__c','FieloPLT__Type__c'});

        System.assertEquals('Member B', members.get(0).Name);
        System.assertEquals('Member C', members.get(1).Name);
        System.assertEquals('Member A', members.get(2).Name);

        SObjectUtils.bulkAssign(members, membersBKPMap, new Set<String>{'Id','Name','FieloPLT__Email__c','FieloPLT__Program__c','FieloPLT__Type__c'});

        Map<Id, FieloPLT__Member__c> membersMap = new Map<Id, FieloPLT__Member__c>(members);

        System.assertEquals('Member A', members.get(0).Name);
        System.assertEquals('Member B', members.get(1).Name);
        System.assertEquals('Member C', members.get(2).Name);
    }

    @istest
    static void getMapByField() {
        FieloPLT__Program__c program = new FieloPLT__Program__c(
            Name = 'Program',
            FieloPLT__OnlineTransactionProcessing__c = true,
            FieloPLT__EnableIncentivesCalculator__c = true
        );

        insert program;

        FieloPLT__Member__c memberA = new FieloPLT__Member__c(
            Name = 'Member A',
            FieloPLT__Email__c = ('Member A').deleteWhitespace() + Datetime.now().getTime() + '@fielo.com',
            FieloPLT__Program__c = program.Id,
            FieloPLT__Type__c = 'Individual Account'
        );
        FieloPLT__Member__c memberB = new FieloPLT__Member__c(
            Name = 'Member B',
            FieloPLT__Email__c = ('Member B').deleteWhitespace() + Datetime.now().getTime() + '@fielo.com',
            FieloPLT__Program__c = program.Id,
            FieloPLT__Type__c = 'Individual Account'
        );
        FieloPLT__Member__c memberC = new FieloPLT__Member__c(
            Name = 'Member C',
            FieloPLT__Email__c = ('Member C').deleteWhitespace() + Datetime.now().getTime() + '@fielo.com',
            FieloPLT__Program__c = program.Id,
            FieloPLT__Type__c = 'Individual Account'
        );
        insert new List<FieloPLT__Member__c>{memberA,memberB,memberC};

        List<FieloPLT__Member__c> members = (List<FieloPLT__Member__c>) Database.query(
            'SELECT ' +
                String.join(new List<String>(SObjectType.FieloPLT__Member__c.fields.getMap().keySet()),',') +
            ' FROM FieloPLT__Member__c'
        );

        Map<String,SObject> recordsMap = SObjectUtils.getMapByField('FieloPLT__ExternalId__c', members);

        Map<Object,SObject> recordsMapAnyType = SObjectUtils.getMapByAnyTypeField('FieloPLT__ExternalId__c', members);
    }

    @isTest
    static void getChildRelationships() {
        Map<String, Schema.ChildRelationship> childRels = SObjectUtils.getChildRelationships('FieloPLT__Member__c');
        Map<String, Schema.ChildRelationship> childRels1 = SObjectUtils.getChildRelationships(FieloPLT__Member__c.sobjecttype);
        Map<String, Schema.ChildRelationship> childRels2 = SObjectUtils.getChildRelationships(sobjecttype.FieloPLT__Member__c);

        System.assert(childRels.keySet().containsAll(childRels1.keySet()));
        System.assert(childRels.keySet().containsAll(childRels2.keySet()));
        System.assert(childRels1.keySet().containsAll(childRels.keySet()));
        System.assert(childRels1.keySet().containsAll(childRels2.keySet()));
        System.assert(childRels2.keySet().containsAll(childRels.keySet()));
        System.assert(childRels2.keySet().containsAll(childRels1.keySet()));
    }

    @istest
    static void getFieldDescribe() {
        DescribeFieldResult fieldDescribe = SObjectUtils.getFieldDescribe('FieloPLT__Rule__c', 'FieloPLT__Promotion__r.FieloPLT__Program__r.Name');
        DescribeFieldResult fieldDescribe1 = SObjectUtils.getFieldDescribe(FieloPLT__Rule__c.sobjecttype, 'FieloPLT__Promotion__r.FieloPLT__Program__r.Name');
        DescribeFieldResult fieldDescribe2 = SObjectUtils.getFieldDescribe(sobjecttype.FieloPLT__Rule__c, 'FieloPLT__Promotion__r.FieloPLT__Program__r.Name');

        System.assertEquals(fieldDescribe.getSobjectField(),fieldDescribe1.getSobjectField());
        System.assertEquals(fieldDescribe.getSobjectField(),fieldDescribe2.getSobjectField());
        System.assertEquals(fieldDescribe1.getSobjectField(),fieldDescribe.getSobjectField());
        System.assertEquals(fieldDescribe1.getSobjectField(),fieldDescribe2.getSobjectField());
        System.assertEquals(fieldDescribe2.getSobjectField(),fieldDescribe.getSobjectField());
        System.assertEquals(fieldDescribe2.getSobjectField(),fieldDescribe1.getSobjectField());
    }

    @istest
    static void getFieldsFromRelationshipType() {
        Map<String, DescribeFieldResult> fieldsMap = SObjectUtils.getFieldsFromRelationshipType('FieloPLT__Transaction__c', 'FieloPLT__Member__c');

        System.assert(fieldsMap.containsKey('FieloPLT__Member__c'));
    }

    @istest
    static void denormalizeRecords() {
        FieloPLT__Program__c program = new FieloPLT__Program__c(
            Name = 'Program',
            FieloPLT__OnlineTransactionProcessing__c = true,
            FieloPLT__EnableIncentivesCalculator__c = true
        );

        insert program;

        FieloPLT__Member__c memberA = new FieloPLT__Member__c(
                Name = 'Member A',
                FieloPLT__Email__c = ('Member A').deleteWhitespace() + Datetime.now().getTime() + '@fielo.com',
                FieloPLT__Program__c = program.Id,
                FieloPLT__Type__c = 'Individual Account'
        );
        FieloPLT__Member__c memberb = new FieloPLT__Member__c(
            Name = 'Member B',
            FieloPLT__Email__c = ('Member B').deleteWhitespace() + Datetime.now().getTime() + '@fielo.com',
            FieloPLT__Program__c = program.Id,
            FieloPLT__Type__c = 'Individual Account'
        );
        insert new List<FieloPLT__Member__c>{memberA,memberB};

        List<FieloPLT__Member__c> members = (List<FieloPLT__Member__c>) Database.query(
            'SELECT ' +
                String.join(new List<String>(SObjectType.FieloPLT__Member__c.fields.getMap().keySet()),',') +
                ',FieloPLT__Program__r.'+String.join(new List<String>(SObjectType.FieloPLT__Program__c.fields.getMap().keySet()),',FieloPLT__Program__r.') +
            ' FROM FieloPLT__Member__c'
        );

        List<Map<String,Object>> result = SObjectUtils.denormalizeRecords(members);

        System.assertEquals('Program', String.valueOf(result.get(0).get('FieloPLT__Program__r.Name')));
        System.assertEquals(true, Boolean.valueOf(result.get(0).get('FieloPLT__Program__r.FieloPLT__OnlineTransactionProcessing__c')));
    }

    @istest
    static void getExternalIdField() {
        System.assertEquals('FieloPLT__ExternalId__c', SObjectUtils.getExternalIdField('FieloPLT__Member__c'));
        System.assertEquals('FieloPLT__ExternalId__c', SObjectUtils.getExternalIdField(FieloPLT__Member__c.sobjecttype));
        System.assertEquals('FieloPLT__ExternalId__c', SObjectUtils.getExternalIdField(sobjecttype.FieloPLT__Member__c));

        System.assertEquals('FieloPLT__ExternalId__c', SObjectUtils.getExternalIdField('FieloPLT__RuleTrigger__c'));
        System.assertEquals('FieloPLT__ExternalId__c', SObjectUtils.getExternalIdField(FieloPLT__RuleTrigger__c.sobjecttype));
        System.assertEquals('FieloPLT__ExternalId__c', SObjectUtils.getExternalIdField(sobjecttype.FieloPLT__RuleTrigger__c));
    }

    @istest
    static void addFields() {
        FieloPLT__Program__c program = new FieloPLT__Program__c(
            Name = 'Program',
            FieloPLT__OnlineTransactionProcessing__c = true,
            FieloPLT__EnableIncentivesCalculator__c = true
        );

        insert program;

        FieloPLT__Member__c memberA = new FieloPLT__Member__c(
            Name = 'Member A',
            FieloPLT__Email__c = ('Member A').deleteWhitespace() + Datetime.now().getTime() + '@fielo.com',
            FieloPLT__Program__c = program.Id,
            FieloPLT__Type__c = 'Individual Account'
        );
        FieloPLT__Member__c memberB = new FieloPLT__Member__c(
            Name = 'Member B',
            FieloPLT__Email__c = ('Member B').deleteWhitespace() + Datetime.now().getTime() + '@fielo.com',
            FieloPLT__Program__c = program.Id,
            FieloPLT__Type__c = 'Individual Account'
        );
        FieloPLT__Member__c memberC = new FieloPLT__Member__c(
            Name = 'Member C',
            FieloPLT__Email__c = ('Member C').deleteWhitespace() + Datetime.now().getTime() + '@fielo.com',
            FieloPLT__Program__c = program.Id,
            FieloPLT__Type__c = 'Individual Account'
        );
        insert new List<FieloPLT__Member__c>{memberA,memberB,memberC};

        List<FieloPLT__Member__c> members = (List<FieloPLT__Member__c>) Database.query(
            'SELECT ' +
                String.join(new List<String>(SObjectType.FieloPLT__Member__c.fields.getMap().keySet()),',') +
            ' FROM FieloPLT__Member__c'
        );

        Map<String, Object> fieldsMap = new Map<String, Object>();

        SObjectUtils.addFields(
            members.get(0),
            members.get(0).getPopulatedFieldsAsMap().keySet(),
            fieldsMap,
            new Set<String>{'Id'}
        );
    }

    @istest
    static void getFieldNameLike() {
        String lastModifiedDateField = SObjectUtils.getFieldNameLike('FieloPLT__Member__c', 'Program');
        String lastModifiedDateField1 = SObjectUtils.getFieldNameLike(FieloPLT__Member__c.sobjectType, 'Program');
        String lastModifiedDateField2 = SObjectUtils.getFieldNameLike(sobjectType.FieloPLT__Member__c, 'Program');

        System.assertEquals(lastModifiedDateField, lastModifiedDateField1);
        System.assertEquals(lastModifiedDateField, lastModifiedDateField2);
    }

    @istest
    static void deleteDuplicateFields() {
        set<String> fields1 = SObjectUtils.deleteDuplicateFields(new Set<String>{'Name','nAmE','NAME',' Name '});
        set<String> fields2 = SObjectUtils.deleteDuplicateFields(new Set<String>{'Name','nAmE','NAME',' Name '});

        System.assert(fields1.equals(fields2));
    }
}
