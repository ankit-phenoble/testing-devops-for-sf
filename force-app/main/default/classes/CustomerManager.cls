public class CustomerManager {

    public static List<Account> getAccounts() {
        return [
            SELECT Id, Name, Industry, Phone
            FROM Account
            LIMIT 10
        ];
    }
}