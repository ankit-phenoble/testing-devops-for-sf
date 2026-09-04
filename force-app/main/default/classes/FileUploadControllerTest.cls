@isTest
private class FileUploadControllerTest {

    private static String getFakeBase64() {
        return EncodingUtil.base64Encode(Blob.valueOf('Hello Audio Test'));
    }

    @testSetup
    static void setupTestData() {
        List<Account> accounts = new List<Account>();
        accounts.add(new Account(Name = 'Test Account'));
        insert accounts;

        List<Contact> contacts = new List<Contact>();
        contacts.add(new Contact(FirstName = 'Test', LastName = 'Contact', AccountId = accounts[0].Id));
        insert contacts;

        List<Opportunity> opportunities = new List<Opportunity>();
        opportunities.add(new Opportunity(Name = 'Test Opportunity', StageName = 'Prospecting', CloseDate = Date.today().addDays(30), AccountId = accounts[0].Id));
        insert opportunities;
    }

    @isTest
    static void testSaveFile_WithContact() {
        Map<Id, Contact> contactMap = new Map<Id, Contact>([SELECT Id FROM Contact LIMIT 1]);
        Test.startTest();
        Map<String, String> result = FileUploadController.saveFile(getFakeBase64(), 'TestRecording', contactMap.values()[0].Id, 90);
        Test.stopTest();
        Assert.areEqual('success', result.get('status'), 'Status should be success');
        Assert.areNotEqual(null, result.get('contentVersionId'), 'ContentVersion ID should be returned');
        Assert.areNotEqual(null, result.get('audioRecordingId'), 'AudioRecording ID should be returned');

        Map<Id, ContentVersion> cvMap = new Map<Id, ContentVersion>([SELECT Id, Title, PathOnClient FROM ContentVersion WHERE  Id = :result.get('contentVersionId')]);
        Assert.areEqual(1, cvMap.size(), 'One ContentVersion should be created');

        Map<Id, Audio_Recording__c> recMap = new Map<Id, Audio_Recording__c>([
            SELECT Id, Recording_Name__c, Duration_Minutes__c,
                   Status__c, Related_Contact__c, File_Name__c
            FROM   Audio_Recording__c
            WHERE  Id = :result.get('audioRecordingId')
        ]);
        Assert.areEqual('TestRecording', recMap.values()[0].Recording_Name__c,  'Recording name should match');
        Assert.areEqual(contactMap.values()[0].Id, recMap.values()[0].Related_Contact__c, 'Related Contact should be set');
    }

    @isTest
    static void testSaveFile_WithAccount() {
        Map<Id, Account> accountMap = new Map<Id, Account>([SELECT Id FROM Account LIMIT 1]);
        Test.startTest();
        Map<String, String> result = FileUploadController.saveFile(getFakeBase64(), 'AccountRecording', accountMap.values()[0].Id, 60);
        Test.stopTest();
        Assert.areEqual('success', result.get('status'), 'Status should be success');
        Map<Id, Audio_Recording__c> recMap = new Map<Id, Audio_Recording__c>([
            SELECT Id, Related_Account__c, Duration_Minutes__c
            FROM   Audio_Recording__c
            WHERE  Id = :result.get('audioRecordingId')
        ]);
        Assert.areEqual(accountMap.values()[0].Id, recMap.values()[0].Related_Account__c,   'Related Account should be set');
    }

    @isTest
    static void testSaveFile_WithOpportunity() {
        Map<Id, Opportunity> oppMap = new Map<Id, Opportunity>([SELECT Id FROM Opportunity LIMIT 1]);
        Test.startTest();
        Map<String, String> result = FileUploadController.saveFile(getFakeBase64(), 'OppRecording', oppMap.values()[0].Id, 125);
        Test.stopTest();
        Assert.areEqual('success', result.get('status'), 'Status should be success');
        Map<Id, Audio_Recording__c> recMap = new Map<Id, Audio_Recording__c>([
            SELECT Id, Related_Opportunity__c, Duration_Minutes__c
            FROM   Audio_Recording__c
            WHERE  Id = :result.get('audioRecordingId')
        ]);
        Assert.areEqual(oppMap.values()[0].Id,  recMap.values()[0].Related_Opportunity__c, 'Related Opportunity should be set');
    }

    @isTest
    static void testSaveFile_WithNoRecId() {
        Test.startTest();
        Map<String, String> result = FileUploadController.saveFile(getFakeBase64(), 'NoParentRecording', null, 45);
        Test.stopTest();
        Assert.areEqual('success', result.get('status'), 'Status should be success');
        Assert.areNotEqual(null, result.get('contentVersionId'), 'ContentVersion should still be created');
        Assert.areNotEqual(null, result.get('audioRecordingId'), 'Audio_Recording__c should still be created');
        Map<Id, Audio_Recording__c> recMap = new Map<Id, Audio_Recording__c>([
            SELECT Id, Related_Contact__c, Related_Account__c,
                   Related_Opportunity__c, Duration_Minutes__c
            FROM   Audio_Recording__c
            WHERE  Id = :result.get('audioRecordingId')
        ]);
        Assert.areEqual(null, recMap.values()[0].Related_Contact__c,     'Related Contact should be null');
        Assert.areEqual(null, recMap.values()[0].Related_Account__c,     'Related Account should be null');
        Assert.areEqual(null, recMap.values()[0].Related_Opportunity__c, 'Related Opportunity should be null');
    }

    @isTest
    static void testSaveFile_InvalidBase64_ThrowsException() {
        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            FileUploadController.saveFile('NOT!!VALID!!BASE64', 'BadFile', null, 30);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();
        Assert.areEqual(true, exceptionThrown, 'AuraHandledException should be thrown for invalid base64');
    }
}