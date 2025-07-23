public with sharing class MessagingServiceController {
    public static final String SCRT_URL = '';
    public static final String ORG_ID = '';
    public static final String ES_DEPLOYMENT_NAME = '';

    private static String accessToken;

    private static Map<String, Object> buildErrorResponse(String error) {
        return new Map<String, Object>{
            'success' => false,
            'error' => error
        };
    }

    @AuraEnabled
    public static Map<String, Object> startConversation() {
        Map<String, Object> result = new Map<String, Object>();
        try {
            fetchAccessToken();

            HttpRequest req = new HttpRequest();
            req.setEndpoint(SCRT_URL + '/iamessage/api/v2/conversation');
            req.setMethod('POST');
            req.setHeader('Authorization', 'Bearer ' + accessToken);
            req.setHeader('Content-Type', 'application/json');

            Map<String, Object> body = new Map<String, Object>{
                'conversationId' => String.valueOf(UUID.randomUUID()).toLowerCase(),
                'esDeveloperName' => ES_DEPLOYMENT_NAME,
            };
            req.setBody(JSON.serialize(body));

            HttpResponse res = new Http().send(req);
            if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                result.put('success', true);
                result.put('conversation', responseMap);
                return result;
            } else {
                return buildErrorResponse('Failed to start conversation: ' + res.getBody());
            }
        } catch (Exception e) {
            return buildErrorResponse('startConversation failed: ' + e.getMessage());
        }
    }


    @AuraEnabled
    public static void sendMessageToAgent(String conversationId, String text) {
        try {
            fetchAccessToken();

            HttpRequest req = new HttpRequest();
            req.setEndpoint(SCRT_URL + '/iamessage/api/v2/conversation/' + conversationId + '/message'); // corrected endpoint
            req.setMethod('POST');
            req.setHeader('Authorization', 'Bearer ' + accessToken);
            req.setHeader('Content-Type', 'application/json');

            Map<String, Object> messagePayload = new Map<String, Object>{
                'message' => new Map<String, Object>{
                    'id' => String.valueOf(Crypto.getRandomLong()), // unique ID
                    'messageType' => 'StaticContentMessage',
                    'staticContent' => new Map<String, Object>{
                        'formatType' => 'Text',
                        'text' => text
                    }
                },
                'esDeveloperName' => ES_DEPLOYMENT_NAME,
                'isNewMessagingSession' => false,
                'language' => 'en'
            };

            req.setBody(JSON.serialize(messagePayload));

            HttpResponse res = new Http().send(req);
            System.debug('sendMessage response status: ' + res.getStatusCode());
            System.debug('sendMessage response: ' + res.getBody());

            if (res.getStatusCode() >= 300) {
                throw new AuraHandledException('Failed to send message (HTTP ' + res.getStatusCode() + '): ' + res.getBody());
            }
        } catch (Exception e) {
            String msg = (e != null && e.getMessage() != null) ? e.getMessage() : 'Unknown error in sendMessageToAgent';
            System.debug('Error in sendMessageToAgent: ' + msg);
            throw new AuraHandledException('sendMessageToAgent failed: ' + msg);
        }
    }

    @AuraEnabled
    public static String getMessages(String conversationId) {
        try {
            fetchAccessToken();

            HttpRequest req = new HttpRequest();
            req.setEndpoint(SCRT_URL + '/iamessage/api/v2/conversation/' + conversationId + '/messages');
            req.setMethod('GET');
            req.setHeader('Authorization', 'Bearer ' + accessToken);

            HttpResponse res = new Http().send(req);
            System.debug('getMessages response: ' + res.getBody());

            if (res.getStatusCode() != 200) {
                throw new AuraHandledException('Failed to retrieve messages (HTTP ' + res.getStatusCode() + '): ' + res.getBody());
            }

            return res.getBody();
        } catch (Exception e) {
            String msg = (e != null && e.getMessage() != null) ? e.getMessage() : 'Unknown error in getMessages';
            System.debug('Error in getMessages: ' + msg);
            throw new AuraHandledException('getMessages failed: ' + msg);
        }
    }

    private static void fetchAccessToken() {
        if (accessToken != null) return;

        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(SCRT_URL + '/iamessage/api/v2/authorization/unauthenticated/access-token');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');

            Map<String, Object> context = new Map<String, Object>{
                'appName' => 'ChatterboxesVoiceApp',
                'clientVersion' => '1.0.0'
            };

            Map<String, Object> body = new Map<String, Object>{
                'orgId' => ORG_ID,
                'esDeveloperName' => ES_DEPLOYMENT_NAME,
                'capabilitiesVersion' => '1',
                'platform' => 'Web',
                'context' => context
            };

            req.setBody(JSON.serialize(body));

            System.debug('Sending fetchAccessToken request to: ' + req.getEndpoint());
            System.debug('Request body: ' + req.getBody());

            HttpResponse res = new Http().send(req);
            System.debug('Access token response status: ' + res.getStatusCode());
            System.debug('Access token response body: ' + res.getBody());

            if (res.getStatusCode() != 200) {
                throw new AuraHandledException('Failed to fetch access token (HTTP ' + res.getStatusCode() + '): ' + res.getBody());
            }

            Map<String, Object> json = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            accessToken = (String) json.get('accessToken');
        } catch (Exception e) {
            String msg = (e != null && e.getMessage() != null) ? e.getMessage() : 'Unknown error in fetchAccessToken';
            System.debug('Error in fetchAccessToken(): ' + msg);
            throw new AuraHandledException('fetchAccessToken failed: ' + msg);
        }
    }
}
