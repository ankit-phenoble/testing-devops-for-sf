public class SoleraWebhookTest {
    
    public static void sendTestPayload() {
        
        Map<String,Object> payload = new Map<String,Object>();
        
        payload.put(
            'header',
            new Map<String,Object>{
                'messageType' => 'Assignment'
            }
        );
        
        payload.put(
            'body',
            new Map<String,Object>{
                'bmsVer'      => '5.8',
                'claimNumber' => 'TEST-CLAIM-001',
                'content'     => 'dGVzdCBjb250ZW50IGJhc2U2NA=='  // dummy base64
            }
        );
        
        payload.put(
            'responseRoute',
            new Map<String,Object>{
                'authorization' => new Map<String,Object>{
                    'href' => 'https://abc.sandbox.my.salesforce.com/services/oauth2/token',
                    'body' => new Map<String,Object>{
                        'Client_Id'     => '{!$Credential.Solera_Test_ExtCred.ClientId}',
                        'Client_Secret' => '{!$Credential.Solera_Test_ExtCred.ClientSecret}',
                        'audience'      => '',
                        'scope'         => ''
                    }
                },
                'responseMessage' => new List<Map<String,Object>>{
                    new Map<String,Object>{ 'type' => 'Assignment', 'href' => '' },
                    new Map<String,Object>{ 'type' => 'ValuationReturn', 'href' => '' }
                }
            }
        );
        
        String jsonBody = JSON.serialize(payload);
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Solera_Test_NC');
       // req.setEndpoint('https://webhook.site/0f5dc9ee-4671-4d19-aaaa-4189b59bf8c0');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(jsonBody);
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        System.debug('Status Code: ' + res.getStatusCode());
        System.debug('Response Body: ' + res.getBody());
    }
}