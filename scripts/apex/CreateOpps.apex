/**
 * Opportunities
 * - Members: Tom Ripley & Jane Grey
 * - CloseDate: second half of 2021
 * - Status: Prospecting
 * - Amount: from $50,000 to $200,000
 * - How many records: 15 per member
 * - Product family: professional license and standard license
 */

List<FieloPLT__Member__c> members = [SELECT Id FROM FieloPLT__Member__c];
List<Account> accs = [SELECT Id, Name FROM Account WHERE NOT(Name like 'Fielo%' OR Name like 'New Roots' OR Name Like 'sForce')];
List<PricebookEntry> pbes = [SELECT Id, Product2.Name, Pricebook2Id, Product2.Family FROM PricebookEntry Where Pricebook2.Name = 'Standard' AND Product2.Family = 'License'];

System.assertEquals(false, members.isEmpty(),    'No Member Found');
System.assertEquals(false, accs.isEmpty(),       'No Account Found');
System.assertEquals(false, pbes.isEmpty(),       'No Pricebook entry found Found');

List<Opportunity> opps = new List<Opportunity>();
List<OpportunityLineItem> oppProducts = new List<OpportunityLineItem>();

// Convert to DateTime values
DateTime mint = Date.newInstance(System.today().year(),6,1);
DateTime maxt = Date.newInstance(System.today().year(),12,31);

// Then convert to milliseconds since Jan 1, 1970, and get difference in ms
Long minms = mint.getTime();
Long maxms = maxt.getTime();
Long diff = maxms - minms;

Map<Integer, Integer> monthsSummary = new Map<Integer, Integer>();
Map<String, Integer> familySummary = new Map<String, Integer>();
Map<String, Integer> productSummary = new Map<String, Integer>();

for(FieloPLT__Member__c member : members) {
    for(Integer i=1;i<=15;i++) {
        Date closeDate = DateTime.newInstance( minms + Math.mod(Math.abs(Crypto.getRandomLong()), diff) ).dateGMT();
        PricebookEntry pbe = pbes.get(Integer.valueof((Math.random() * pbes.size())));
        Account acc = accs.get(Integer.valueof((Math.random() * accs.size())));

        String monthStr = String.valueOf(closeDate.month());
        String yearStr = String.valueOf(closeDate.year());
        opps.add(
            new Opportunity(
                Name = String.format('{0} - {1}.{2}-{3}',
                    new List<String> {
                        acc.Name,
                        yearStr,
                        monthStr.leftPad(2,'0').substring(monthStr.leftPad(2,'0').length()-2),
                        String.valueOf(i).leftPad(4,'0').substring(String.valueOf(i).leftPad(4,'0').length()-4)
                    }
                ),
                CloseDate = closeDate,
                AccountId = acc.Id,
                Member__c = member.Id,
                StageName = 'Prospecting',
                Pricebook2Id = pbe.Pricebook2Id
            )
        );

        oppProducts.add(
            new OpportunityLineItem(
                Opportunity = opps.get(opps.size()-1),
                PricebookEntryId = pbe.Id,
                Quantity = 1,
                TotalPrice = 50000 + ( Integer.valueof((Math.random() * 150000 )) )
            )
        );

        Integer month = closeDate.month();
        String family = pbe.Product2.Family;
        String name = pbe.Product2.Name;

        if (monthsSummary.get(month) != null) {
            monthsSummary.put(month, monthsSummary.get(month) + 1);
        } else {
            monthsSummary.put(month, 1);
        }

        if (familySummary.get(family) != null) {
            familySummary.put(family, familySummary.get(family) + 1);
        } else {
            familySummary.put(family, 1);
        }

        if (productSummary.get(name) != null) {
            productSummary.put(name, productSummary.get(name) + 1);
        } else {
            productSummary.put(name, 1);
        }
    }
}

System.debug('Opps: ' + opps.size());
System.debug('PppProducts: ' + oppProducts.size());
System.debug('monthsSummary: ' + JSON.serializePretty(monthsSummary));
System.debug('familySummary: ' + JSON.serializePretty(familySummary));
System.debug('productSummary: ' + JSON.serializePretty(productSummary));
System.debug('Opp Sample: ' + JSON.serializePretty(opps[0]));
System.debug('Opp Product Sample: ' + JSON.serializePretty(oppProducts[0]));

Savepoint sp = Database.setSavepoint();
try {
    if (!opps.isEmpty()) {
        insert opps;

        if (!opps.isEmpty()) {
            for(OpportunityLineItem oli : oppProducts) {
                oli.OpportunityId = oli.Opportunity.Id;
                oli.Opportunity = null;
            }
            insert oppProducts;
        }
    }
} catch (Exception e) {
    Database.rollback(sp);
    System.debug(e.getMessage());
}
// Database.rollback(sp);