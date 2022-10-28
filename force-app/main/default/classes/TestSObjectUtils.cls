@isTest
public class TestSObjectUtils {

    @isTest
    static void denormalizeRecords() {
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


        List<Map<String,Object>> result = SObjectUtils.denormalizeRecords(
            Database.query(
                'SELECT ' +
                    String.join(new List<String>(SObjectType.Contact.fields.getMap().keySet()), ', ') + ', ' +
                    'Account.' + String.join(new List<String>(SObjectType.Account.fields.getMap().keySet()), ',Account.') +
                ' FROM Contact'
            )
        );
    }
}
