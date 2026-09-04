@IsTest
private class AIRecordSummaryControllerTest {

    private static final String MOCK_SUMMARY_JSON = '{"revenue":"$5M","employees":"200","rating":"Hot","overview":"Test overview.","opportunity":"Test opportunity.","watchout":"Test watchout.","nextstep":"Test next step."}';
    private static final String MOCK_FOLLOWUP_RESPONSE = 'This account has 3 open opportunities totalling $150,000.';
    private static final String ACCOUNT_NAME_ACME = 'Acme Corp';
    private static final String ACCOUNT_NAME_MINIMAL = 'Minimal Corp';

    @TestSetup
    private static void setupTestData() {
        List<Account> accounts = new List<Account>{
            new Account(Name = ACCOUNT_NAME_ACME, Industry = 'Technology', Type = 'Customer', 
                       AnnualRevenue = 5000000, NumberOfEmployees = 200, Rating = 'Hot'),
            new Account(Name = ACCOUNT_NAME_MINIMAL)
        };
        insert accounts;
        
        Map<String, Id> accountIds = new Map<String, Id>();
        for (Account acc : accounts) accountIds.put(acc.Name, acc.Id);
        
        insert new List<Contact>{
            new Contact(FirstName = 'Alice', LastName = 'Anderson', AccountId = accountIds.get(ACCOUNT_NAME_ACME)),
            new Contact(FirstName = 'Bob', LastName = 'Baker', AccountId = accountIds.get(ACCOUNT_NAME_ACME))
        };
        
        insert new List<Opportunity>{
            new Opportunity(Name = 'Acme Deal Alpha', AccountId = accountIds.get(ACCOUNT_NAME_ACME), 
                           StageName = 'Proposal/Price Quote', Amount = 75000, CloseDate = Date.today().addDays(30)),
            new Opportunity(Name = 'Acme Deal Beta', AccountId = accountIds.get(ACCOUNT_NAME_ACME),
                           StageName = 'Needs Analysis', Amount = 120000, CloseDate = Date.today().addDays(60))
        };
        
        insert new List<Case>{
            new Case(Subject = 'Integration issue', Status = 'Open', AccountId = accountIds.get(ACCOUNT_NAME_ACME)),
            new Case(Subject = 'Billing query', Status = 'Closed', AccountId = accountIds.get(ACCOUNT_NAME_ACME))
        };
    }

    private static Id getAccountId(String accountName) {
        return [SELECT Id FROM Account WHERE Name = :accountName LIMIT 1].Id;
    }
    
    @IsTest
    private static void testGetRecordSummary_Success() {
        Test.setMock(HttpCalloutMock.class, new OpenAIMockSuccess(MOCK_SUMMARY_JSON));
        
        Test.startTest();
        String result = AIRecordSummaryController.getRecordSummary(getAccountId(ACCOUNT_NAME_ACME));
        Test.stopTest();
        
        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(result);
        Assert.areEqual('$5M', parsed.get('revenue'));
        Assert.areEqual('200', parsed.get('employees'));
        Assert.areEqual('Test overview.', parsed.get('overview'));
    }

    @IsTest
    private static void testGetRecordSummary_MinimalAccount() {
        Test.setMock(HttpCalloutMock.class, new OpenAIMockSuccess(
            '{"revenue":"N/A","employees":"N/A","rating":"N/A","overview":"Minimal.","opportunity":"Unknown.","watchout":"None.","nextstep":"Qualify."}'));
        
        Test.startTest();
        String result = AIRecordSummaryController.getRecordSummary(getAccountId(ACCOUNT_NAME_MINIMAL));
        Test.stopTest();
        
        Assert.isNotNull(result);
    }

    @IsTest
    private static void testGetRecordSummary_OpenAiError() {
        Test.setMock(HttpCalloutMock.class, new OpenAIMockError(500));
        
        Test.startTest();
        try {
            AIRecordSummaryController.getRecordSummary(getAccountId(ACCOUNT_NAME_ACME));
            Assert.fail('Expected exception was not thrown');
        } catch (Exception ex) {
            Assert.isTrue(true, 'Exception caught as expected');
        }
        Test.stopTest();
    }

    @IsTest
    private static void testGetRecordSummary_InvalidId() {
        Test.startTest();
        try {
            AIRecordSummaryController.getRecordSummary('001000000000001');
            Assert.fail('Expected exception was not thrown');
        } catch (Exception ex) {
            Assert.isTrue(true, 'Exception caught as expected');
        }
        Test.stopTest();
    }

    @IsTest
    private static void testGetAccountSnapshot_Success() {
        Test.startTest();
        String result = AIRecordSummaryController.getAccountSnapshot(getAccountId(ACCOUNT_NAME_ACME));
        Test.stopTest();
        
        Map<String, Object> snapshot = (Map<String, Object>) JSON.deserializeUntyped(result);
        Assert.isTrue(((List<Object>) snapshot.get('relatedContacts')).size() >= 2);
        Assert.isTrue(((List<Object>) snapshot.get('relatedOpportunities')).size() >= 2);
    }

    @IsTest
    private static void testGetAccountSnapshot_MinimalAccount() {
        Test.startTest();
        String result = AIRecordSummaryController.getAccountSnapshot(getAccountId(ACCOUNT_NAME_MINIMAL));
        Test.stopTest();
        
        Map<String, Object> snapshot = (Map<String, Object>) JSON.deserializeUntyped(result);
        Assert.areEqual(0, ((List<Object>) snapshot.get('relatedContacts')).size());
    }

    @IsTest
    private static void testGetAccountSnapshot_InvalidId() {
        Test.startTest();
        try {
            AIRecordSummaryController.getAccountSnapshot(null);
            Assert.fail('Expected exception was not thrown');
        } catch (Exception ex) {
            Assert.isTrue(true, 'Exception caught as expected');
        }
        Test.stopTest();
    }

    @IsTest
    private static void testAskFollowUpQuestion_Success() {
        String history = JSON.serialize(new List<Map<String, String>>{
            new Map<String, String>{'role' => 'user', 'content' => 'Previous question?'},
            new Map<String, String>{'role' => 'assistant', 'content' => 'Previous answer.'}
        });
        
        Test.setMock(HttpCalloutMock.class, new OpenAIMockSuccess(MOCK_FOLLOWUP_RESPONSE));
        
        Test.startTest();
        String result = AIRecordSummaryController.askFollowUpQuestion(
            getAccountId(ACCOUNT_NAME_ACME), history, 'How many opportunities?');
        Test.stopTest();
        
        Assert.areEqual(MOCK_FOLLOWUP_RESPONSE, result);
    }

    @IsTest
    private static void testAskFollowUpQuestion_EmptyHistory() {
        Test.setMock(HttpCalloutMock.class, new OpenAIMockSuccess(MOCK_FOLLOWUP_RESPONSE));
        
        Test.startTest();
        String result = AIRecordSummaryController.askFollowUpQuestion(
            getAccountId(ACCOUNT_NAME_ACME), JSON.serialize(new List<Object>()), 'Summarize?');
        Test.stopTest();
        
        Assert.isNotNull(result);
    }

    @IsTest
    private static void testAskFollowUpQuestion_OpenAiError() {
        Test.setMock(HttpCalloutMock.class, new OpenAIMockError(429));
        
        Test.startTest();
        try {
            AIRecordSummaryController.askFollowUpQuestion(
                getAccountId(ACCOUNT_NAME_ACME), '[]', 'Question?');
            Assert.fail('Expected exception was not thrown');
        } catch (Exception ex) {
            Assert.isTrue(true, 'Exception caught as expected');
        }
        Test.stopTest();
    }
    
    @IsTest
    private static void testAskFollowUpQuestion_MalformedHistory() {
        Test.setMock(HttpCalloutMock.class, new OpenAIMockSuccess(MOCK_FOLLOWUP_RESPONSE));
        
        Test.startTest();
        try {
            AIRecordSummaryController.askFollowUpQuestion(
                getAccountId(ACCOUNT_NAME_ACME), 'INVALID_JSON_HISTORY', 'Question?');
            Assert.fail('Expected exception was not thrown');
        } catch (Exception ex) {
            Assert.isTrue(true, 'Exception caught as expected');
        }
        Test.stopTest();
    }

    private class OpenAIMockSuccess implements HttpCalloutMock {
        private final String content;
        OpenAIMockSuccess(String content) { 
            this.content = content; 
        }
        
        public HTTPResponse respond(HTTPRequest req) {
            Map<String, Object> response = new Map<String, Object>{
                'choices' => new List<Object>{
                    new Map<String, Object>{
                        'message' => new Map<String, Object>{
                            'role' => 'assistant', 
                            'content' => content
                        }
                    }
                }
            };
            HTTPResponse res = new HTTPResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody(JSON.serialize(response));
            return res;
        }
    }

    private class OpenAIMockError implements HttpCalloutMock {
        private final Integer statusCode;
        OpenAIMockError(Integer statusCode) { 
            this.statusCode = statusCode; 
        }
        
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setStatusCode(statusCode);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"error":{"message":"API Error"}}');
            return res;
        }
    }
}