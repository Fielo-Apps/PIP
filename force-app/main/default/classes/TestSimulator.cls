@isTest
public class TestSimulator {
    @isTest
    static void testSimulate(){
        FieloPLT__Program__c program = new FieloPLT__Program__c(
            Name = 'Program',
            FieloPLT__OnlineTransactionProcessing__c = true,
            FieloPLT__EnableIncentivesCalculator__c = true
        );

        insert program;

        FieloPLT__ProgramPointType__c ppt = [SELECT FieloPLT__PointType__c FROM FieloPLT__ProgramPointType__c];

        List<FieloPLT__Segment__c> segments = new List<FieloPLT__Segment__c>{
            new FieloPLT__Segment__c(
                Name = 'Segment',
                RecordTypeId = Schema.SObjectType.FieloPLT__Segment__c.getRecordTypeInfosByName().get('Dynamic').getRecordTypeId(),
                FieloPLT__Program__c = program.Id,
                FieloPLT__LogicalExpression__c = 'ALL',
                FieloPLT__ExternalId__c = guid(),
                FieloPLT__isActive__c = true
            )
        };
        insert segments;

        List<FieloPLT__Criterion__c> segcriteria = new List<FieloPLT__Criterion__c>{
            new FieloPLT__Criterion__c(
                FieloPLT__Segment__c = segments.get(0).Id,
                FieloPLT__ExternalId__c = guid(),
                FieloPLT__FieldName__c = 'FieloPLT__Type__c',
                FieloPLT__FieldType__c = 'Text',
                FieloPLT__Values__c = 'Individual Account',
                FieloPLT__Operator__c = 'equals'
            )
        };

        insert segcriteria;

        FieloPLT__Member__c member = new FieloPLT__Member__c(
            Name = 'Member A',
            FieloPLT__Email__c = ('Member A').deleteWhitespace() + Datetime.now().getTime() + '@fielo.com',
            FieloPLT__Program__c = program.Id,
            FieloPLT__Type__c = 'Individual Account'
        );
        insert member;

        FieloPLT__RuleTrigger__c rt = new FieloPLT__RuleTrigger__c(
			Name = 'Event',
			FieloPLT__Object__c = 'FieloPLT__Event__c',
			FieloPLT__ConditionField__c = 'FieloPLT__Type__c',
			FieloPLT__ConditionValue__c = 'Login',
			FieloPLT__Date__c = 'CreatedDate',
			FieloPLT__LookupFromTransaction__c = 'FieloPLT__Event__c',
			FieloPLT__Prefix__c = ((sObject)Type.forName('FieloPLT__Event__c').newInstance()).getSObjectType().getDescribe().getKeyPrefix(),
			FieloPLT__ExternalId__c = guid(),
			FieloPLT__Status__c = 'Active'
		);
        insert rt;

        FieloPLT__Action__c action = new FieloPLT__Action__c(
            Name = 'Generate Event And Win',
			FieloPLT__TargetMember__c = 'FieloPLT__Member__c',
			FieloPLT__RuleTrigger__c = rt.Id,
			FieloPLT__ConditionField__c = 'FieloPLT__Type__c',
			FieloPLT__conditionValue__c = 'Login',
			FieloPLT__ExternalId__c = guid()
		);
        insert action;

        List<FieloPLT__Promotion__c> promotions = new List<FieloPLT__Promotion__c>{
            new FieloPLT__Promotion__c(
                Name = 'Promotion A',
                FieloPLT__Program__c = program.Id,
                FieloPLT__ExternalId__c = guid(),
                FieloPLT__Segment__c = segments.get(0).Id
            )
        };
        insert promotions;

        List<FieloPLT__Rule__c> rules = new List<FieloPLT__Rule__c>{
            new FieloPLT__Rule__c(
                Name = 'Rule A',
                FieloPLT__Promotion__c = promotions.get(0).Id,
                FieloPLT__ExternalId__c = guid(),
                FieloPLT__PointConversionMode__c = 'Fixed Value',
                FieloPLT__ConversionValue__c = 500,
                FieloPLT__Action__c = action.Id,
                FieloPLT__LogicalExpression__c = 'ALL',
                FieloPLT__Type__c = 'No Competition'
            ),
            new FieloPLT__Rule__c(
                Name = 'Rule B',
                FieloPLT__Promotion__c = promotions.get(0).Id,
                FieloPLT__ExternalId__c = guid(),
                FieloPLT__PointConversionMode__c = 'Fixed Value',
                FieloPLT__ConversionValue__c = 200,
                FieloPLT__Action__c = action.Id,
                FieloPLT__LogicalExpression__c = 'ALL',
                FieloPLT__Type__c = 'No Competition'
            )
        };
        insert rules;

        List<FieloPLT__Criterion__c> criteria = new List<FieloPLT__Criterion__c>{
            new FieloPLT__Criterion__c(
                FieloPLT__Rule__c = rules.get(0).Id,
                FieloPLT__ExternalId__c = guid(),
                FieloPLT__FieldName__c = 'FieloPLT__Value__c',
                FieloPLT__FieldType__c = 'Number',
                FieloPLT__NumberValue__c = 50,
                FieloPLT__Operator__c = 'greater than'
            )
        };
        insert criteria;

        promotions.get(0).FieloPLT__Status__c = 'Active';
        update promotions;

        insert new FieloPLT__SimulationSettings__c(
            Name = 'Even Simulation',
            FieloPLT__Object__c = 'FieloPLT__Event__c',
            FieloPLT__Program__c = program.Id,
            FieloPLT__Currencies__c = String.valueOf(ppt.FieloPLT__PointType__c),
            FieloPLT__Actions__c = String.valueOf(action.Id)
        );

        startTest();
            List<FieloPLT__Event__c> events = new List<FieloPLT__Event__c>();
            events.add(new FieloPLT__Event__c(FieloPLT__Member__c = member.Id, FieloPLT__Value__c = 100));
            events.add(new FieloPLT__Event__c(FieloPLT__Member__c = member.Id, FieloPLT__Value__c = 150));
            insert events;

            Object currencyMap = SimpleSimulatorController.simulate(member.Id, events);
        stopTest();
    }

    @isTest
    static void testGetRecords() {
        FieloPLT__Program__c program = new FieloPLT__Program__c(
            Name = 'Program',
            FieloPLT__OnlineTransactionProcessing__c = true,
            FieloPLT__EnableIncentivesCalculator__c = true
        );

        insert program;

        FieloPLT__Member__c member = new FieloPLT__Member__c(
            Name = 'Member A',
            FieloPLT__Email__c = ('Member A').deleteWhitespace() + Datetime.now().getTime() + '@fielo.com',
            FieloPLT__Program__c = program.Id,
            FieloPLT__Type__c = 'Individual Account'
        );
        insert member;

        List<FieloPLT__Event__c> events = new List<FieloPLT__Event__c>{
            new FieloPLT__Event__c(FieloPLT__Member__c = member.Id, FieloPLT__Value__c = 100),
            new FieloPLT__Event__c(FieloPLT__Member__c = member.Id, FieloPLT__Value__c = 150)
        };
        insert events;

         FieloPLT__RuleTrigger__c rt = new FieloPLT__RuleTrigger__c(
			Name = 'Event',
			FieloPLT__Object__c = 'FieloPLT__Event__c',
			FieloPLT__ConditionField__c = 'FieloPLT__Type__c',
			FieloPLT__ConditionValue__c = 'Login',
			FieloPLT__Date__c = 'CreatedDate',
			FieloPLT__LookupFromTransaction__c = 'FieloPLT__Event__c',
			FieloPLT__Prefix__c = ((sObject)Type.forName('FieloPLT__Event__c').newInstance()).getSObjectType().getDescribe().getKeyPrefix(),
			FieloPLT__ExternalId__c = guid(),
			FieloPLT__Status__c = 'Active'
		);
        insert rt;

        Map<String,CriteriaWrapper> criteriasMapByObject = new Map<String,CriteriaWrapper>();
        criteriasMapByObject.put('rules', new CriteriaWrapper());
        criteriasMapByObject.get('rules').fieldsByObject = new Map<String,Set<String>>{
            'FieloPLT__Event__c' => new Set<String>(Schema.SObjectType.FieloPLT__Event__c.fields.getMap().keySet())
        };

        FieloPLT__Action__c action = new FieloPLT__Action__c(
            Name = 'Generate Event And Win',
			FieloPLT__TargetMember__c = 'FieloPLT__Member__c',
			FieloPLT__RuleTrigger__c = rt.Id,
			FieloPLT__ConditionField__c = 'FieloPLT__Type__c',
			FieloPLT__conditionValue__c = 'Login',
			FieloPLT__ExternalId__c = guid()
		);
        insert action;

        FieloPLT__Triggers__c triggers = FieloPLT__Triggers__c.getInstance(UserInfo.getUserId());
        triggers.FieloPLT__Criterion__c = false;
        upsert triggers;

        update new FieloPLT__Action__c (
            Id = action.Id,
            FieloPLT__CriteriaFields__c = JSON.serialize(criteriasMapByObject)
        );

        List<Map<String,String>> relatedLists = SimulatorService.getRelatedLists('FieloPLT__Event__c', null);

        Object records = SimpleSimulatorController.getRecords(member.Id, 'FieloPLT__Event__c', '');
    }

    @isTest
    static void getWiredRecords() {
        FieloPLT__Program__c program = new FieloPLT__Program__c(
            Name = 'Program',
            FieloPLT__OnlineTransactionProcessing__c = true,
            FieloPLT__EnableIncentivesCalculator__c = true
        );

        insert program;

        FieloPLT__Member__c member = new FieloPLT__Member__c(
            Name = 'Member A',
            FieloPLT__Email__c = ('Member A').deleteWhitespace() + Datetime.now().getTime() + '@fielo.com',
            FieloPLT__Program__c = program.Id,
            FieloPLT__Type__c = 'Individual Account'
        );
        insert member;

        List<FieloPLT__Event__c> events = new List<FieloPLT__Event__c>{
            new FieloPLT__Event__c(FieloPLT__Member__c = member.Id, FieloPLT__Value__c = 100),
            new FieloPLT__Event__c(FieloPLT__Member__c = member.Id, FieloPLT__Value__c = 150)
        };
        insert events;

         FieloPLT__RuleTrigger__c rt = new FieloPLT__RuleTrigger__c(
			Name = 'Event',
			FieloPLT__Object__c = 'FieloPLT__Event__c',
			FieloPLT__ConditionField__c = 'FieloPLT__Type__c',
			FieloPLT__ConditionValue__c = 'Login',
			FieloPLT__Date__c = 'CreatedDate',
			FieloPLT__LookupFromTransaction__c = 'FieloPLT__Event__c',
			FieloPLT__Prefix__c = ((sObject)Type.forName('FieloPLT__Event__c').newInstance()).getSObjectType().getDescribe().getKeyPrefix(),
			FieloPLT__ExternalId__c = guid(),
			FieloPLT__Status__c = 'Active'
		);
        insert rt;

        Map<String,CriteriaWrapper> criteriasMapByObject = new Map<String,CriteriaWrapper>();
        criteriasMapByObject.put('rules', new CriteriaWrapper());
        criteriasMapByObject.get('rules').fieldsByObject = new Map<String,Set<String>>{
            'FieloPLT__Event__c' => new Set<String>(Schema.SObjectType.FieloPLT__Event__c.fields.getMap().keySet())
        };

        FieloPLT__Action__c action = new FieloPLT__Action__c(
            Name = 'Generate Event And Win',
			FieloPLT__TargetMember__c = 'FieloPLT__Member__c',
			FieloPLT__RuleTrigger__c = rt.Id,
			FieloPLT__ConditionField__c = 'FieloPLT__Type__c',
			FieloPLT__conditionValue__c = 'Login',
			FieloPLT__ExternalId__c = guid()
		);
        insert action;

        FieloPLT__Triggers__c triggers = FieloPLT__Triggers__c.getInstance(UserInfo.getUserId());
        triggers.FieloPLT__Criterion__c = false;
        upsert triggers;

        update new FieloPLT__Action__c (
            Id = action.Id,
            FieloPLT__CriteriaFields__c = JSON.serialize(criteriasMapByObject)
        );

        List<SObject> records = SimulatorService.getWiredRecords(
            String.join(new List<String>(Schema.SObjectType.FieloPLT__Event__c.fields.getMap().keySet()), ','),
            'FieloPLT__Event__c',
            JSON.serialize(new Map<String,String>{'FieloPLT__Member__c' => String.valueOf(member.Id)}),
            null,
            '10',
            '0'
        );
    }

    @isTest
    static void testGetPathLabel() {
        SimulatorService.getPathLabel('FieloPLT__Point__c', 'FieloPLT__Transaction__r.FieloPLT__Member__r.FieloPLT__Program__r.Name');
    }

    @isTest
    static void testGetWhereCondition() {
        String whereCondition = SimulatorService.getWhereCondition(
            JSON.serialize(
                new Map<String,String>{
                    'FieloPLT__Program__c' => 'null',
                    'Name' => '!null',
                    'FieloPLT__IsActive__c' => 'BOOLEAN:true'
                }
            ),
            'FieloPLT__Segment__c'
        );

        whereCondition = SimulatorService.getWhereCondition(
            JSON.serialize(
                new Map<String,String>{
                    'FieloPLT__Program__c' => 'null',
                    'Name' => 'LIKE:Bronze',
                    'FieloPLT__IsActive__c' => 'BOOLEAN:true'
                }
            ),
            'FieloPLT__Segment__c'
        );

        whereCondition = SimulatorService.getWhereCondition(
            JSON.serialize(
                new Map<String,String>{
                    'FieloPLT__Program__c' => 'null',
                    'Name' => '!Manual Segment',
                    'FieloPLT__IsActive__c' => 'BOOLEAN:true'
                }
            ),
            'FieloPLT__Segment__c'
        );

        whereCondition = SimulatorService.getWhereCondition(
            JSON.serialize(
                new Map<String,String>{
                    'FieloPLT__Value__c' => 'FROM:0TO:100',
                    'FieloPLT__Value__c' => 'FROM:0',
                    'FieloPLT__Value__c' => 'IN:1,2,3'
                }
            ),
            'FieloPLT__Event__c'
        );

        whereCondition = SimulatorService.getWhereCondition(
            JSON.serialize(
                new Map<String,String>{
                    'FieloPLT__Date__c' => '2021-01-01TO:2021-02-01'
                }
            ),
            'FieloPLT__Event__c'
        );
    }

    @isTest
    static void testGetPrograms() {
        FieloPLT__Program__c program = new FieloPLT__Program__c(
            Name = 'Program',
            FieloPLT__OnlineTransactionProcessing__c = true,
            FieloPLT__EnableIncentivesCalculator__c = true
        );

        insert program;

        List<FieloPLT__Program__c> programs = (List<FieloPLT__Program__c>) SimpleSimulatorController.getPrograms();
    }

    @isTest
    static void testTranslate() {
        FieloPLT__Program__c program = new FieloPLT__Program__c(
            Name = 'Program',
            FieloPLT__OnlineTransactionProcessing__c = true,
            FieloPLT__EnableIncentivesCalculator__c = true
        );

        insert program;

        FieloPLT__ProgramPointType__c ppt = [SELECT FieloPLT__PointType__c FROM FieloPLT__ProgramPointType__c];

        List<FieloPLT__Segment__c> segments = new List<FieloPLT__Segment__c>{
            new FieloPLT__Segment__c(
                Name = 'Segment',
                RecordTypeId = Schema.SObjectType.FieloPLT__Segment__c.getRecordTypeInfosByName().get('Dynamic').getRecordTypeId(),
                FieloPLT__Program__c = program.Id,
                FieloPLT__LogicalExpression__c = 'ALL',
                FieloPLT__ExternalId__c = guid(),
                FieloPLT__isActive__c = true
            )
        };
        insert segments;

        List<Id> idsToTranslate = new List<Id>();

        idsToTranslate.add(program.Id);
        idsToTranslate.add(ppt.FieloPLT__PointType__c);
        idsToTranslate.add(segments.get(0).Id);

        Map<String, String> translatedIds = (Map<String, String>) SimpleSimulatorController.translateIds(idsToTranslate);
    }

    public static string guid() {
        String h = EncodingUtil.ConvertTohex(Crypto.GenerateAESKey(128));
        String guid = h.SubString(0,8)+ '-' + h.SubString(8,12) + '-' + h.SubString(12,16) + '-' + h.SubString(16,20) + '-' + h.substring(20);
        return guid;
    }

    public static void startTest(){
		Test.startTest();
		FieloPLT.sObjectService.enableAdminPermission(false);
		FieloPLT.sObjectService.setStaticVariables();
	}

    public static void stopTest(){
		Test.stopTest();
		FieloPLT.SObjectService.enableAdminPermission(true);
	}

    public class CriteriaWrapper{
        public Boolean isCrossField;
        public Boolean isMasterDetail;
        public Boolean isUsingCriterionGroup;
        public Map<String,Set<String>> fieldsByObject;
        public Map<String,String> pointLookupByObject;

        public CriteriaWrapper(){
            this.isCrossField = false;
            this.isMasterDetail = false;
            this.isUsingCriterionGroup = false;
            this.fieldsByObject = new Map<String,Set<String>>();
            this.pointLookupByObject = new Map<String,String>();
        }
    }
}
