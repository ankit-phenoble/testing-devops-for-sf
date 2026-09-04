public with sharing class ContactService {

    public static void updateContactTitles(List<Contact> contactsToUpdate) {
        if (contactsToUpdate == null || contactsToUpdate.isEmpty()) {
            return;
        }

        for (Contact contactRecord : contactsToUpdate) {
            if (String.isBlank(contactRecord.Title)) {
                contactRecord.Title = 'New Contact';
            }
        }

        update contactsToUpdate;
    }
}