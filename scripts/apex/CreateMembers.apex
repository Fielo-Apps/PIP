/**
 * @brief       Script to create 200 members from static resource
 *
 * @details     There should be already 1 program in the org
 *              The script will create 1 account (if it does not exist) and
 *              200 members assigned to it
 */

List<FieloPLT__Program__c> programs = [SELECT Id FROM FieloPLT__Program__c WHERE Name = 'Default'];
if (programs.isEmpty()) {
    programs.add(new FieloPLT__Program__c(
        Name = 'Default',
        FieloPLT__OnlineTransactionProcessing__c = true//,
    ));
    insert programs;
}

FieloPLT__Settings__c settings = FieloPLT__Settings__c.getInstance(UserInfo.getUserId());
settings.FieloPLT__CurrentProgramId__c = programs[0].Id;
upsert settings;

List<FieloPLT__Member__c> members = new List<FieloPLT__Member__c>();

List<Contact> contactsInOrg = [SELECT Id, Name, AccountId, Email FROM Contact WHERE AccountId != null AND Account.Name != 'Fielo Members' AND Email != ''];

if (!contactsInOrg.isEmpty()) {
    for(Contact c : contactsInOrg) {
        members.add(
            new FieloPLT__Member__c(
                Name = c.Name,
                FieloPLT__Email__c = c.Email.replaceAll('[^a-zA-Z0-9@.]+',''),
                FieloPLT__Program__c = programs.get(0).Id,
                FieloPLT__Account__c = c.AccountId,
                FieloPLT__Contact__c = c.Id
            )
        );
    }
}

List<StaticResource> defaultResource = [Select  s.Body From StaticResource s where s.Name LIKE 'memberNames'];

if (!defaultResource.isEmpty()) {
    blob resourseBody = defaultResource.get(0).Body;
    String contentFile = resourseBody.toString();
    List<String> filelines = contentFile.split('\n');
    List<String> inputvalues;

    List<Account> fieloAcc = [SELECT Id FROM Account WHERE Name = 'Fielo Members'];

    if (fieloAcc.isEmpty()) {
        fieloAcc.add(new Account(Name='Fielo Members'));
        insert fieloAcc;
    }

    String memberName;
    for (Integer i=0;i<filelines.size();i++) {
        inputvalues = filelines[i].split(',');
        memberName = String.format('{0} {1}', new List<String>{
            inputvalues[0],
            inputvalues[1]
        });
        members.add(
            new FieloPLT__Member__c(
                Name = memberName,
                FieloPLT__Email__c = (memberName).trim().replace(' ','.') + '@email.com',
                FieloPLT__Program__c = programs.get(0).Id,
                FieloPLT__Account__c = fieloAcc.get(0).Id
            )
        );
    }
}

if (!members.isEmpty()) {
    insert members;
}
