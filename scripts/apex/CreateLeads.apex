/**
 * Leads (if possible)
 * - Members: Tom Ripley
 * - Status: Open - Not Contacted
 * - How many records: 20
 */
List<FieloPLT__Member__c> members = [SELECT Id FROM FieloPLT__Member__c WHERE Name = 'Tom Ripley'];
List<Account> accs = [SELECT Id, Name FROM Account WHERE Name = 'New Roots'];

System.assertEquals(false, members.isEmpty(),    'No Member Found');
System.assertEquals(false, accs.isEmpty(),       'No Account Found');

String contentFile = [Select s.Body From StaticResource s where s.Name LIKE 'memberNames']?.get(0).Body.toString();

System.assert(String.isNotBlank(contentFile), 'memberNames not found');

List<String> filelines = contentFile.split('\n');
List<String> firstNameList = new List<String>();
List<String> lastNameList = new List<String>();

for (Integer i=0;i<filelines.size();i++) {
    List<String> inputvalues = filelines[i].split(',');
    firstNameList.add(inputvalues[0]);
    lastNameList.add(inputvalues[1]);
}

List<Lead> leads = new List<Lead>();

String firstName, lastName;
Integer fNameIndex, lNameIndex;
for(Integer i = 1; i <= 20; i++) {
    fNameIndex = Integer.valueof(Math.random() * firstNameList.size());
    lNameIndex = Integer.valueof(Math.random() * lastNameList.size());

    firstName = firstNameList.remove(fNameIndex);
    lastName = lastNameList.remove(lNameIndex);

    leads.add(new Lead(
        FirstName = firstName,
        LastName = lastName,
        Company = accs.get(0).Name,
        Status = 'Open - Not Contacted',
        Member__c = members.get(0).Id
    ));
}

System.debug(
    JSON.serializePretty(leads)
);

if (leads?.isEmpty() == false)
    insert leads;