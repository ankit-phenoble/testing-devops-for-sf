@IsTest
private class ContactServiceTest {

    @IsTest
    static void updateContactTitles_setsDefaultTitle() {
        Account accountRecord = new Account(
            Name = 'CI Test Account'
        );
        insert accountRecord;

        Contact contactRecord = new Contact(
            FirstName = 'CI',
            LastName = 'Test',
            AccountId = accountRecord.Id
        );
        insert contactRecord;

        Test.startTest();

        ContactService.updateContactTitles(
            new List<Contact>{ contactRecord }
        );

        Test.stopTest();

        Contact updatedContact = [
            SELECT Id, Title
            FROM Contact
            WHERE Id = :contactRecord.Id
        ];

        System.assertEquals(
            'New Contact',
            updatedContact.Title
        );
    }

    @IsTest
    static void updateContactTitles_keepsExistingTitle() {
        Contact contactRecord = new Contact(
            FirstName = 'CI',
            LastName = 'Test',
            Title = 'Developer'
        );
        insert contactRecord;

        Test.startTest();

        ContactService.updateContactTitles(
            new List<Contact>{ contactRecord }
        );

        Test.stopTest();

        Contact updatedContact = [
            SELECT Id, Title
            FROM Contact
            WHERE Id = :contactRecord.Id
        ];

        System.assertEquals(
            'Developer',
            updatedContact.Title
        );
    }
}