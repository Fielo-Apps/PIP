@isTest
public class TestSObjectSelector {

    @isTest
    static void getRecord() {
        Account acc = new Account(
            Name = 'Burlington'
        );
        insert acc;

        Contact con = new Contact(
            FirstName = 'John',
            LastName = 'Logan',
            AccountId = acc.Id
        );
        insert con;

        Contact con2 = (Contact) SObjectSelector.getRecord(con.Id);
        Contact con3 = (Contact) SObjectSelector.getRecord(con.Id, true);
        Contact con4 = ((List<Contact>) SObjectSelector.getRecords(new List<Id>{con.Id})).get(0);
        Contact con5 = ((List<Contact>) SObjectSelector.getRecords(new Set<Id>{con.Id})).get(0);

        System.assertEquals(con.Id, con2.Id, 'Wrong Contact Id');
        System.assertEquals(con.Id, con3.Id, 'Wrong Contact Id');
        System.assertEquals(con.Id, con4.Id, 'Wrong Contact Id');
        System.assertEquals(con.Id, con5.Id, 'Wrong Contact Id');
    }
}
