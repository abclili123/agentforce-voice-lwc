public with sharing class MessagingServiceController {
    public static final String SCRT_URL = 'https://orgfarm-7428735f60-dev-ed.develop.my.salesforce-scrt.com';
    public static final String ORG_ID = '00DgL000006ain3';
    public static final String ES_DEPLOYMENT_NAME = 'Chatterbox_Custom_Front_End';

    private static String accessToken;
    
    @AuraEnabled
    public static String startConversation() {
        fetchAccessToken();
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint(SCRT_URL + '/iamessage/api/v2/conversations');
        req.setMethod('POST');
        req.setHeader('Authorization', 'Bearer ' + accessToken);
        req.setHeader('Content-Type', 'application/json');

        Map<String, Object> body = new Map<String, Object>{
            'conversationId' => generateUUID(),
            'esDeveloperName' => ES_DEPLOYMENT_NAME
        };
        req.setBody(JSON.serialize(body));

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 200) {
            throw new AuraHandledException('Failed to start conversation: ' + res.getBody());
        }

        return res.getBody(); // returns JSON string with conversationId
    }

    @AuraEnabled
    public static void sendMessageToAgent(String conversationId, String text) {
        fetchAccessToken();

        HttpRequest req = new HttpRequest();
        req.setEndpoint(SCRT_URL + '/iamessage/api/v2/conversations/' + conversationId + '/messages');
        req.setMethod('POST');
        req.setHeader('Authorization', 'Bearer ' + accessToken);
        req.setHeader('Content-Type', 'application/json');

        Map<String, Object> body = new Map<String, Object>{
            'message' => new Map<String, Object>{
                'type' => 'Text',
                'text' => text
            }
        };
        req.setBody(JSON.serialize(body));

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() >= 300) {
            throw new AuraHandledException('Failed to send message: ' + res.getBody());
        }
    }

    @AuraEnabled
    public static String getMessages(String conversationId) {
        fetchAccessToken();

        HttpRequest req = new HttpRequest();
        req.setEndpoint(SCRT_URL + '/iamessage/api/v2/conversations/' + conversationId + '/messages');
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + accessToken);

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 200) {
            throw new AuraHandledException('Failed to retrieve messages: ' + res.getBody());
        }

        return res.getBody();
    }

    private static void fetchAccessToken() {
        if (accessToken != null) return;

        HttpRequest req = new HttpRequest();
        req.setEndpoint(SCRT_URL + '/iamessage/api/v2/authorization/unauthenticated/access-token');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');

        Map<String, Object> body = new Map<String, Object>{
            'orgId' => ORG_ID,
            'esDeveloperName' => ES_DEPLOYMENT_NAME,
            'capabilitiesVersion' => '1',
            'platform' => 'Web'
        };
        req.setBody(JSON.serialize(body));

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 200) {
            throw new AuraHandledException('Failed to fetch access token: ' + res.getBody());
        }

        Map<String, Object> json = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        accessToken = (String) json.get('token');
    }

    private static String generateUUID() {
        return String.valueOf(Crypto.getRandomLong()).replace('-', '') + String.valueOf(Crypto.getRandomLong()).replace('-', '');
    }
}
