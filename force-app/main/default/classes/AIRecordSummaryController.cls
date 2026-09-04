public with sharing class AIRecordSummaryController {

    // Constants
    private static final String OPENAI_ENDPOINT = 'callout:OpenAI/v1/chat/completions';
    private static final String OPENAI_MODEL = 'gpt-4o';
    private static final Integer MAX_TOKENS = 1000;
    private static final Decimal TEMPERATURE = 0.3;
    private static final Integer HTTP_TIMEOUT_MS = 30000;
    private static final Integer RELATED_LIMIT = 5;

    // Public AuraEnabled Methods
    @AuraEnabled
    public static String getRecordSummary(Id recordId) {
        try {
            String accountContext = buildAccountContext(recordId);

            String systemMessage =
                'You are a Salesforce CRM assistant helping sales reps ' +
                'understand their accounts quickly and accurately. ' +
                'Always base your response strictly on the data provided. ' +
                'Never fabricate or assume information not present in the data.';

            String userMessage =
                'Analyze this Salesforce account and respond ONLY with a ' +
                'valid JSON object. No markdown, no explanation, no text ' +
                'outside the JSON.\n\n' +
                'Required JSON structure:\n' +
                '{\n' +
                '  "revenue" : "formatted revenue e.g. $5M or N/A",\n' +
                '  "employees" : "employee count as string or N/A",\n' +
                '  "rating" : "Hot or Warm or Cold or N/A",\n' +
                '  "overview" : "1-2 sentence factual description",\n' +
                '  "opportunity" : "1-2 sentence on business opportunity",\n' +
                '  "watchout" : "1-2 sentence on any risk or anomaly",\n' +
                '  "nextstep" : "1 clear actionable next step"\n' +
                '}\n\n' +
                accountContext;

            List<Map<String, String>> messages = new List<Map<String, String>>{
                buildMessage('system', systemMessage),
                buildMessage('user', userMessage)
            };

            String aiResponse = callOpenAI(messages);
            validateSummaryJSON(aiResponse);
            return aiResponse;

        } catch (AuraHandledException auraEx) {
            throw auraEx;
        } catch (Exception ex) {
            throw new AuraHandledException(
                'Failed to generate summary: ' + ex.getMessage()
            );
        }
    }

    @AuraEnabled(cacheable=true)
    public static String getAccountSnapshot(Id accountId) {
        try {
            Account accountDetails = [
                SELECT Id, Type, Industry, AnnualRevenue, Owner.Name
                FROM Account
                WHERE Id = :accountId
                LIMIT 1
            ];

            List<Contact> relatedContacts = [
                SELECT Id FROM Contact
                WHERE AccountId = :accountId
                LIMIT :RELATED_LIMIT
            ];

            List<Opportunity> relatedOpportunities = [
                SELECT Id FROM Opportunity
                WHERE AccountId = :accountId
                LIMIT :RELATED_LIMIT
            ];

            List<Case> relatedCases = [
                SELECT Id, IsClosed FROM Case
                WHERE AccountId = :accountId
                LIMIT :RELATED_LIMIT
            ];

            List<Task> relatedActivities = [
                SELECT Id FROM Task
                WHERE WhatId = :accountId
                AND IsClosed = false
                LIMIT :RELATED_LIMIT
            ];

            Map<String, Object> snapshotResult = new Map<String, Object>{
                'accountDetails' => accountDetails,
                'relatedContacts' => relatedContacts,
                'relatedOpportunities' => relatedOpportunities,
                'relatedCases' => relatedCases,
                'relatedActivities' => relatedActivities
            };

            return JSON.serialize(snapshotResult);

        } catch (Exception ex) {
            throw new AuraHandledException(
                'Failed to load account snapshot: ' + ex.getMessage()
            );
        }
    }
    @AuraEnabled
    public static String askFollowUpQuestion(
        Id recordId,
        String conversationHistory,
        String userQuestion
    ) {
        try {
            String accountContext = buildAccountContext(recordId);

            String systemMessage =
                'You are a Salesforce CRM assistant. You have detailed ' +
                'knowledge of the following Salesforce account record and ' +
                'its related data. Answer questions accurately and concisely ' +
                'based only on the data provided below. If the answer is not ' +
                'in the data, say so clearly.\n\n' +
                'ACCOUNT CONTEXT:\n' + accountContext;

            // Deserialise existing history from LWC
            List<Object> rawHistory =
                (List<Object>) JSON.deserializeUntyped(conversationHistory);

            // Build full message list: system → history → new user question
            List<Map<String, String>> messages = new List<Map<String, String>>();
            messages.add(buildMessage('system', systemMessage));

            for (Object entry : rawHistory) {
                Map<String, Object> historyEntry =
                    (Map<String, Object>) entry;
                String role = (String) historyEntry.get('role');
                String content = (String) historyEntry.get('content');
                messages.add(buildMessage(role, content));
            }

            messages.add(buildMessage('user', userQuestion));

            return callOpenAI(messages);

        } catch (AuraHandledException auraEx) {
            throw auraEx;
        } catch (Exception ex) {
            throw new AuraHandledException(
                'Failed to process question: ' + ex.getMessage()
            );
        }
    }

    // Private — Data Fetching

    private static String buildAccountContext(Id recordId) {
        Account accountRecord = fetchAccountRecord(recordId);
        List<Contact> contacts = fetchRelatedContacts(recordId);
        List<Opportunity> opps = fetchRelatedOpportunities(recordId);
        List<Case> cases = fetchRelatedCases(recordId);

        String context = formatAccountFields(accountRecord);
        context += formatContactsSection(contacts);
        context += formatOpportunitiesSection(opps);
        context += formatCasesSection(cases);

        return context;
    }

    /** Fetches core Account fields */
    private static Account fetchAccountRecord(Id recordId) {
        return [
            SELECT  Name, Industry, Type, Ownership, AnnualRevenue,NumberOfEmployees,Rating,AccountSource,Website,Phone,Fax,BillingStreet,BillingCity,BillingState,
            BillingPostalCode,BillingCountry,ShippingCity,ShippingCountry,Description,Tier,TickerSymbol,Sic,SicDesc,Parent.Name,Owner.Name,CreatedDate,LastModifiedDate
            FROM Account WHERE Id = :recordId
            LIMIT 1
        ];
    }

    /** Fetches top 5 related Contacts */
    private static List<Contact> fetchRelatedContacts(Id accountId) {
        return [
            SELECT FirstName, LastName,Title,Email,Phone,Department,LeadSource,LastActivityDate
            FROM Contact WHERE AccountId = :accountId ORDER BY LastModifiedDate DESC
            LIMIT :RELATED_LIMIT
        ];
    }

    /** Fetches top 5 related Opportunities */
    private static List<Opportunity> fetchRelatedOpportunities(Id accountId) {
        return [
            SELECT Name, StageName,Amount,CloseDate,Probability,Type,LeadSource,Description,OwnerId,Owner.Name
            FROM Opportunity WHERE AccountId = :accountId ORDER BY CloseDate DESC
            LIMIT :RELATED_LIMIT
        ];
    }

    /** Fetches top 5 related Cases */
    private static List<Case> fetchRelatedCases(Id accountId) {
        return [
            SELECT CaseNumber,Subject,Status,Priority,Origin,Description,CreatedDate,ClosedDate,Owner.Name
            FROM Case WHERE AccountId = :accountId ORDER BY CreatedDate DESC
            LIMIT :RELATED_LIMIT
        ];
    }

    // Private — Context Formatters
    /* Formats core Account fields into readable text */
    private static String formatAccountFields(Account acc) {
        String formatted = '=== ACCOUNT RECORD ===\n';
        formatted += field('Name', acc.Name);
        formatted += field('Industry', acc.Industry);
        formatted += field('Type', acc.Type);
        formatted += field('Ownership', acc.Ownership);
        formatted += field('Annual Revenue', acc.AnnualRevenue != null
                                                ? '$' + String.valueOf(acc.AnnualRevenue)
                                                : null);
        formatted += field('Employees', acc.NumberOfEmployees != null
                                                ? String.valueOf(acc.NumberOfEmployees)
                                                : null);
        formatted += field('Rating', acc.Rating);
        formatted += field('Account Source', acc.AccountSource);
        formatted += field('Website', acc.Website);
        formatted += field('Phone', acc.Phone);
        formatted += field('Billing Location', buildAddress(
                                                acc.BillingCity,
                                                acc.BillingState,
                                                acc.BillingCountry));
        formatted += field('Parent Account', acc.Parent?.Name);
        formatted += field('Account Owner', acc.Owner?.Name);
        formatted += field('Einstein Tier', acc.Tier);
        formatted += field('Ticker Symbol', acc.TickerSymbol);
        formatted += field('SIC Code', acc.Sic);
        formatted += field('SIC Description', acc.SicDesc);
        formatted += field('Description', acc.Description);
        formatted += field('Created Date', acc.CreatedDate != null
                                                ? String.valueOf(acc.CreatedDate.date())
                                                : null);
        formatted += '\n';
        return formatted;
    }

    /** Formats related Contacts into readable text */
    private static String formatContactsSection(List<Contact> contacts) {
        if (contacts.isEmpty()) {
            return '=== RELATED CONTACTS ===\nNo contacts found.\n\n';
        }

        String formatted = '=== RELATED CONTACTS (' + contacts.size() + ') ===\n';
        Integer contactIndex = 1;

        for (Contact eachContact : contacts) {
            formatted += contactIndex + '. ' +
                         eachContact.FirstName + ' ' + eachContact.LastName + '\n';
            formatted += field('   Title', eachContact.Title);
            formatted += field('   Department', eachContact.Department);
            formatted += field('   Email', eachContact.Email);
            formatted += field('   Phone', eachContact.Phone);
            formatted += field('   Lead Source',eachContact.LeadSource);
            formatted += field('   Last Active',eachContact.LastActivityDate != null
                                                ? String.valueOf(eachContact.LastActivityDate)
                                                : null);
            contactIndex++;
        }

        return formatted + '\n';
    }

    /** Formats related Opportunities into readable text */
    private static String formatOpportunitiesSection(List<Opportunity> opportunities) {
        if (opportunities.isEmpty()) {
            return '=== RELATED OPPORTUNITIES ===\nNo opportunities found.\n\n';
        }

        String formatted = '=== RELATED OPPORTUNITIES (' + opportunities.size() + ') ===\n';
        Integer oppIndex = 1;

        for (Opportunity eachOpp : opportunities) {
            formatted += oppIndex + '. ' + eachOpp.Name + '\n';
            formatted += field('   Stage', eachOpp.StageName);
            formatted += field('   Amount', eachOpp.Amount != null
                                                  ? '$' + String.valueOf(eachOpp.Amount)
                                                  : null);
            formatted += field('   Close Date',  eachOpp.CloseDate != null
                                                  ? String.valueOf(eachOpp.CloseDate)
                                                  : null);
            formatted += field('   Probability', eachOpp.Probability != null
                                                  ? String.valueOf(eachOpp.Probability) + '%'
                                                  : null);
            formatted += field('   Type', eachOpp.Type);
            formatted += field('   Owner', eachOpp.Owner?.Name);
            formatted += field('   Description', eachOpp.Description);
            oppIndex++;
        }

        return formatted + '\n';
    }

    /** Formats related Cases into readable text */
    private static String formatCasesSection(List<Case> cases) {
        if (cases.isEmpty()) {
            return '=== RELATED CASES ===\nNo cases found.\n\n';
        }

        String formatted = '=== RELATED CASES (' + cases.size() + ') ===\n';
        Integer caseIndex = 1;

        for (Case eachCase : cases) {
            formatted += caseIndex + '. Case #' + eachCase.CaseNumber +
                         ' — ' + eachCase.Subject + '\n';
            formatted += field('   Status', eachCase.Status);
            formatted += field('   Priority', eachCase.Priority);
            formatted += field('   Origin', eachCase.Origin);
            formatted += field('   Owner', eachCase.Owner?.Name);
            formatted += field('   Created', eachCase.CreatedDate != null
                                                  ? String.valueOf(eachCase.CreatedDate.date())
                                                  : null);
            formatted += field('   Closed',      eachCase.ClosedDate != null
                                                  ? String.valueOf(eachCase.ClosedDate.date())
                                                  : null);
            formatted += field('   Description', eachCase.Description);
            caseIndex++;
        }

        return formatted + '\n';
    }

    // Private — OpenAI Integration

    /*
      Makes the HTTP callout to OpenAI Chat Completions API.
      Accepts a list of role/content message maps.
     */
    private static String callOpenAI(List<Map<String, String>> messages) {
        Map<String, Object> requestPayload = new Map<String, Object>{
            'model' => OPENAI_MODEL,
            'max_tokens'  => MAX_TOKENS,
            'temperature' => TEMPERATURE,
            'messages' => messages
        };

        HttpRequest httpRequest = new HttpRequest();
        httpRequest.setEndpoint(OPENAI_ENDPOINT);
        httpRequest.setMethod('POST');
        httpRequest.setHeader('Content-Type', 'application/json');
        httpRequest.setTimeout(HTTP_TIMEOUT_MS);
        httpRequest.setBody(JSON.serialize(requestPayload));

        HttpResponse httpResponse = new Http().send(httpRequest);

        if (httpResponse.getStatusCode() == 200) {
            return extractOpenAIContent(httpResponse.getBody());
        }

        throw new AuraHandledException(
            'OpenAI returned status ' + httpResponse.getStatusCode() +
            ': ' + httpResponse.getBody()
        );
    }

    /** Extracts the text content from OpenAI response JSON */
    private static String extractOpenAIContent(String responseBody) {
        Map<String, Object> parsedResponse =
            (Map<String, Object>) JSON.deserializeUntyped(responseBody);
        List<Object> choices =
            (List<Object>) parsedResponse.get('choices');
        Map<String, Object> firstChoice =
            (Map<String, Object>) choices[0];
        Map<String, Object> messageObject =
            (Map<String, Object>) firstChoice.get('message');
        return ((String) messageObject.get('content')).trim();
    }

    // Private — Utility Helpers

    // Builds a message map for OpenAI in {role, content} format
    private static Map<String, String> buildMessage(String role, String content) {
        return new Map<String, String>{
            'role'    => role,
            'content' => content
        };
    }

    /*
      Formats a single field as "- Label: Value\n"
      Skips the field entirely if value is null or blank
     */
    private static String field(String label, String value) {
        if (String.isBlank(value)) return '';
        return '- ' + label + ': ' + value + '\n';
    }

    // Combines city, state, country into one readable address string
    private static String buildAddress(
        String city,
        String state,
        String country
    ) {
        List<String> addressParts = new List<String>();
        if (String.isNotBlank(city)) addressParts.add(city);
        if (String.isNotBlank(state)) addressParts.add(state);
        if (String.isNotBlank(country)) addressParts.add(country);
        return addressParts.isEmpty() ? null : String.join(addressParts, ', ');
    }

    /*
     Validates that the AI response contains all required JSON keys
     for the structured summary card.
     */
    private static void validateSummaryJSON(String jsonString) {
        try {
            Map<String, Object> parsedJson =
                (Map<String, Object>) JSON.deserializeUntyped(jsonString);

            List<String> requiredKeys = new List<String>{
                'revenue', 'employees', 'rating',
                'overview', 'opportunity', 'watchout', 'nextstep'
            };

            for (String requiredKey : requiredKeys) {
                if (!parsedJson.containsKey(requiredKey)) {
                    throw new AuraHandledException(
                        'AI response is missing required key: ' + requiredKey
                    );
                }
            }
        } catch (JSONException jsonEx) {
            throw new AuraHandledException(
                'AI returned invalid JSON: ' + jsonEx.getMessage()
            );
        }
    }
}