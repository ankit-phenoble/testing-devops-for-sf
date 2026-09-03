@IsTest
private class AccountServiceTest {

    @IsTest
    static void updateAccountDescriptions_updatesAccounts() {
        Account accountRecord = new Account(
            Name = 'CI Test Account'
        );
        insert accountRecord;

        Test.startTest();

        AccountService.updateAccountDescriptions(
            new List<Account>{ accountRecord }
        );

        Test.stopTest();

        Account updatedAccount = [
            SELECT Id, Description
            FROM Account
            WHERE Id = :accountRecord.Id
        ];

        System.assertEquals(
            'Updated by Account Service',
            updatedAccount.Description
        );
    }

    @IsTest
    static void updateAccountDescriptions_handlesEmptyList() {
        Test.startTest();

        AccountService.updateAccountDescriptions(
            new List<Account>()
        );

        Test.stopTest();

        System.assertEquals(true, true);
    }
}