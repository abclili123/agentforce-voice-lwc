public with sharing class AgentforceService {
    @AuraEnabled
    public static String getResponse(String userInput) {
        // Retrieve Agentforce configuration from custom metadata
        List<Agentforce_Config__mdt> configs = [
            SELECT Agentforce_Endpoint__c, Agentforce_API_Key__c
            FROM Agentforce_Config__mdt
            WHERE DeveloperName = 'Default'
            LIMIT 1
        ];
        String endpoint = configs.isEmpty() ? null : configs[0].Agentforce_Endpoint__c;
        String apiKey = configs.isEmpty() ? null : configs[0].Agentforce_API_Key__c;
        if (endpoint == null || apiKey == null) {
            throw new AuraHandledException('Agentforce configuration is missing.');
        }
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Authorization', 'Bearer ' + apiKey);
        req.setBody(JSON.serialize(new Map<String, String>{ 'input' => userInput }));

        Http http = new Http();
        HttpResponse res = http.send(req);
        return res.getBody();
    }
}
