public with sharing class AccountService {

    /**
     * Updates the Description field for the provided Accounts.
     *
     * @param accountsToUpdate Accounts that need to be updated.
     */
    public static void updateAccountDescriptions(List<Account> accountsToUpdate) {
        if (accountsToUpdate == null || accountsToUpdate.isEmpty()) {
            return;
        }

        for (Account accountRecord : accountsToUpdate) {
            accountRecord.Description = 'Updated by Account Service';
        }

        update accountsToUpdate;
    }
}