/**
 * AgentForceController
 * Handles integration with Salesforce AgentForce for the Voice Assistant
 */
public with sharing class AgentForceController {
    
    // Cache for settings to avoid multiple queries
    private static AgentForce_Settings__mdt cachedSettings;
    
    // Session state
    private static String accessToken;
    private static String instanceUrl;
    private static String sessionId;
    private static Integer sequenceId = 1;
    
    /**
     * Get AgentForce settings from custom metadata
     * @return Map of settings
     */
    @AuraEnabled
    public static Map<String, Object> getAgentForceSettings() {
        try {
            // Get settings from custom metadata
            AgentForce_Settings__mdt settings = getSettings();
            
            // Return as a map for LWC
            Map<String, Object> settingsMap = new Map<String, Object>();
            settingsMap.put('serverUrl', settings.Server_URL__c);
            settingsMap.put('agentId', settings.Agent_ID__c);
            settingsMap.put('enabled', settings.Is_Enabled__c);
            settingsMap.put('orgId', settings.Org_ID__c);
            
            // Don't return sensitive information
            settingsMap.put('clientId', '******');
            settingsMap.put('clientSecret', '******');
            
            return settingsMap;
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching AgentForce settings: ' + e.getMessage());
        }
    }
    
    /**
     * Complete a conversation with AgentForce - authenticate, create session if needed, and send message
     * @param userQuery User's query/message
     * @return Response from AgentForce
     */
    @AuraEnabled
    public static Map<String, Object> completeConversation(String userQuery) {
        try {
            // Get settings
            AgentForce_Settings__mdt settings = getSettings();
            
            // Check if AgentForce is enabled
            if (!settings.Is_Enabled__c) {
                return buildErrorResponse('AgentForce integration is disabled');
            }
            
            // Ensure we have a valid access token
            if (String.isBlank(accessToken)) {
                Map<String, Object> authResult = authenticate();
                if (!(Boolean)authResult.get('success')) {
                    return authResult;
                }
            }
            
            // Ensure we have a valid session
            if (String.isBlank(sessionId)) {
                Map<String, Object> sessionResult = createSession();
                if (!(Boolean)sessionResult.get('success')) {
                    return sessionResult;
                }
            }
            
            // Send the message to the agent
            return sendMessage(userQuery);
        } catch (Exception e) {
            return buildErrorResponse('Error in AgentForce conversation: ' + e.getMessage());
        }
    }
    
    /**
     * Authenticate with the AgentForce API
     * @return Authentication result
     */
    @AuraEnabled
    public static Map<String, Object> authenticate() {
        try {
            // Get settings
            AgentForce_Settings__mdt settings = getSettings();
            
            // Build the token URL
            String tokenUrl = 'https://' + settings.Server_URL__c + '/services/oauth2/token';
            
            // Set up the HTTP request
            HttpRequest req = new HttpRequest();
            req.setEndpoint(tokenUrl);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            
            // Build the request body
            String body = 'grant_type=client_credentials' +
                          '&client_id=' + settings.Client_ID__c +
                          '&client_secret=' + settings.Client_Secret__c;
            
            req.setBody(body);
            req.setTimeout(30000); // 30-second timeout
            
            // Send the request
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            // Process the response
            if (res.getStatusCode() == 200) {
                // Parse the JSON response
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                
                // Extract and store the access token
                accessToken = (String) responseMap.get('access_token');
                instanceUrl = (String) responseMap.get('instance_url');
                
                if (String.isBlank(accessToken)) {
                    return buildErrorResponse('No access token in response');
                }
                
                return buildSuccessResponse('Authentication successful');
            } else {
                String errorMessage = 'Authentication error: ' + res.getStatusCode() + ' ' + res.getStatus();
                System.debug(errorMessage);
                System.debug('Response: ' + res.getBody());
                return buildErrorResponse(errorMessage);
            }
        } catch (Exception e) {
            String errorMessage = 'Exception during authentication: ' + e.getMessage();
            System.debug(errorMessage);
            return buildErrorResponse(errorMessage);
        }
    }
    
    /**
     * Create a new session with an AgentForce agent
     * @return Session creation result
     */
    @AuraEnabled
    public static Map<String, Object> createSession() {
        try {
            // Get settings
            AgentForce_Settings__mdt settings = getSettings();
            
            // Ensure we have a valid access token
            if (String.isBlank(accessToken)) {
                Map<String, Object> authResult = authenticate();
                if (!(Boolean)authResult.get('success')) {
                    return authResult;
                }
            }
            
            // Try API URL format first
            String sessionUrl = 'https://api.salesforce.com/einstein/ai-agent/v1/agents/' + settings.Agent_ID__c + '/sessions';
            
            // Set up the HTTP request
            HttpRequest req = new HttpRequest();
            req.setEndpoint(sessionUrl);
            req.setMethod('POST');
            req.setHeader('Authorization', 'Bearer ' + accessToken);
            req.setHeader('Content-Type', 'application/json');
            
            // Build the request body
            Map<String, Object> requestBody = new Map<String, Object>();
            requestBody.put('externalSessionKey', generateRandomUUID());
            
            Map<String, Object> instanceConfig = new Map<String, Object>();
            instanceConfig.put('endpoint', instanceUrl);
            requestBody.put('instanceConfig', instanceConfig);
            
            Map<String, Object> streamingCapabilities = new Map<String, Object>();
            List<String> chunkTypes = new List<String>{'Text'};
            streamingCapabilities.put('chunkTypes', chunkTypes);
            requestBody.put('streamingCapabilities', streamingCapabilities);
            
            requestBody.put('bypassUser', true);
            
            req.setBody(JSON.serialize(requestBody));
            req.setTimeout(30000); // 30-second timeout
            
            // Send the request
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            // Process the response
            if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
                // Parse the JSON response
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                
                // Extract and store the session ID
                sessionId = (String) responseMap.get('sessionId');
                sequenceId = 1;
                
                if (String.isBlank(sessionId)) {
                    return buildErrorResponse('No session ID in response');
                }
                
                return buildSuccessResponse('Session created successfully');
            } else {
                // Try alternative URL format if first attempt fails
                if (sessionUrl.startsWith('https://api.salesforce.com')) {
                    return createSessionWithAlternateUrl(settings);
                } else {
                    String errorMessage = 'Session creation error: ' + res.getStatusCode() + ' ' + res.getStatus();
                    System.debug(errorMessage);
                    System.debug('Response: ' + res.getBody());
                    
                    // If unauthorized, try to reauthenticate and retry
                    if (res.getStatusCode() == 401) {
                        System.debug('Token expired, reauthenticating...');
                        Map<String, Object> authResult = authenticate();
                        if ((Boolean)authResult.get('success')) {
                            return createSession();
                        }
                    }
                    
                    return buildErrorResponse(errorMessage);
                }
            }
        } catch (Exception e) {
            String errorMessage = 'Exception during session creation: ' + e.getMessage();
            System.debug(errorMessage);
            return buildErrorResponse(errorMessage);
        }
    }
    
    /**
     * Try to create a session with an alternate URL format
     * @param settings AgentForce settings
     * @return Session creation result
     */
    private static Map<String, Object> createSessionWithAlternateUrl(AgentForce_Settings__mdt settings) {
        try {
            // Try alternate URL format
            String altSessionUrl = instanceUrl + '/services/data/v59.0/einstein/ai-agent/agents/' + settings.Agent_ID__c + '/sessions';
            
            // Set up the HTTP request
            HttpRequest req = new HttpRequest();
            req.setEndpoint(altSessionUrl);
            req.setMethod('POST');
            req.setHeader('Authorization', 'Bearer ' + accessToken);
            req.setHeader('Content-Type', 'application/json');
            
            // Build the request body
            Map<String, Object> requestBody = new Map<String, Object>();
            requestBody.put('externalSessionKey', generateRandomUUID());
            
            Map<String, Object> instanceConfig = new Map<String, Object>();
            instanceConfig.put('endpoint', instanceUrl);
            requestBody.put('instanceConfig', instanceConfig);
            requestBody.put('bypassUser', true);
            
            req.setBody(JSON.serialize(requestBody));
            req.setTimeout(30000); // 30-second timeout
            
            // Send the request
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            // Process the response
            if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
                // Parse the JSON response
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                
                // Extract and store the session ID
                sessionId = (String) responseMap.get('sessionId');
                sequenceId = 1;
                
                if (String.isBlank(sessionId)) {
                    return buildErrorResponse('No session ID in response from alternate URL');
                }
                
                return buildSuccessResponse('Session created successfully with alternate URL');
            } else {
                String errorMessage = 'Session creation error with alternate URL: ' + res.getStatusCode() + ' ' + res.getStatus();
                System.debug(errorMessage);
                System.debug('Response: ' + res.getBody());
                
                return buildErrorResponse(errorMessage);
            }
        } catch (Exception e) {
            String errorMessage = 'Exception during session creation with alternate URL: ' + e.getMessage();
            System.debug(errorMessage);
            return buildErrorResponse(errorMessage);
        }
    }
    
    /**
     * Send a message to the AgentForce agent and get the response
     * @param message Message to send to the agent
     * @return Agent response
     */
    @AuraEnabled
    public static Map<String, Object> sendMessage(String message) {
        try {
            // Validate inputs
            if (String.isBlank(message)) {
                return buildErrorResponse('Message is required');
            }
            
            // Ensure we have a valid session
            if (String.isBlank(sessionId)) {
                Map<String, Object> sessionResult = createSession();
                if (!(Boolean)sessionResult.get('success')) {
                    return sessionResult;
                }
            }
            
            // Try API URL format first
            String messageUrl = 'https://api.salesforce.com/einstein/ai-agent/v1/sessions/' + sessionId + '/messages';
            
            // Set up the HTTP request
            HttpRequest req = new HttpRequest();
            req.setEndpoint(messageUrl);
            req.setMethod('POST');
            req.setHeader('Authorization', 'Bearer ' + accessToken);
            req.setHeader('Content-Type', 'application/json');
            
            // Build the request body
            Map<String, Object> requestBody = new Map<String, Object>();
            
            Map<String, Object> messageObj = new Map<String, Object>();
            messageObj.put('sequenceId', sequenceId);
            messageObj.put('type', 'Text');
            messageObj.put('text', message);
            
            requestBody.put('message', messageObj);
            
            req.setBody(JSON.serialize(requestBody));
            req.setTimeout(120000); // 2-minute timeout
            
            // Send the request
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            // Process the response
            if (res.getStatusCode() == 200) {
                // Parse the JSON response
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                
                // Extract the agent response
                String agentResponse = '';
                
                if (responseMap.containsKey('messages') && responseMap.get('messages') != null) {
                    List<Object> messages = (List<Object>) responseMap.get('messages');
                    if (!messages.isEmpty()) {
                        Map<String, Object> firstMessage = (Map<String, Object>) messages[0];
                        agentResponse = (String) firstMessage.get('message');
                    }
                }
                
                if (String.isBlank(agentResponse)) {
                    agentResponse = 'No response from agent';
                }
                
                // Increment the sequence ID for the next message
                sequenceId++;
                
                // Build the success response
                Map<String, Object> result = buildSuccessResponse('Message sent successfully');
                result.put('agentResponse', agentResponse);
                result.put('nextSequenceId', sequenceId);
                
                return result;
            } else {
                // Try alternative URL format if first attempt fails
                if (messageUrl.startsWith('https://api.salesforce.com')) {
                    return sendMessageWithAlternateUrl(message);
                } else {
                    String errorMessage = 'Message sending error: ' + res.getStatusCode() + ' ' + res.getStatus();
                    System.debug(errorMessage);
                    System.debug('Response: ' + res.getBody());
                    
                    // If unauthorized, try to reauthenticate and retry
                    if (res.getStatusCode() == 401) {
                        System.debug('Token expired, reauthenticating...');
                        Map<String, Object> authResult = authenticate();
                        if ((Boolean)authResult.get('success')) {
                            return sendMessage(message);
                        }
                    }
                    
                    // If session expired or not found, create a new session and retry
                    if (res.getStatusCode() == 404) {
                        System.debug('Session not found, creating new session...');
                        sessionId = null;
                        Map<String, Object> sessionResult = createSession();
                        if ((Boolean)sessionResult.get('success')) {
                            return sendMessage(message);
                        }
                    }
                    
                    return buildErrorResponse(errorMessage);
                }
            }
        } catch (Exception e) {
            String errorMessage = 'Exception during message sending: ' + e.getMessage();
            System.debug(errorMessage);
            return buildErrorResponse(errorMessage);
        }
    }
    
    /**
     * Try to send a message with an alternate URL format
     * @param message Message to send to the agent
     * @return Agent response
     */
    private static Map<String, Object> sendMessageWithAlternateUrl(String message) {
        try {
            // Try alternate URL format
            String altMessageUrl = instanceUrl + '/services/data/v59.0/einstein/ai-agent/sessions/' + sessionId + '/messages';
            
            // Set up the HTTP request
            HttpRequest req = new HttpRequest();
            req.setEndpoint(altMessageUrl);
            req.setMethod('POST');
            req.setHeader('Authorization', 'Bearer ' + accessToken);
            req.setHeader('Content-Type', 'application/json');
            
            // Build the request body
            Map<String, Object> requestBody = new Map<String, Object>();
            
            Map<String, Object> messageObj = new Map<String, Object>();
            messageObj.put('sequenceId', sequenceId);
            messageObj.put('type', 'Text');
            messageObj.put('text', message);
            
            requestBody.put('message', messageObj);
            
            req.setBody(JSON.serialize(requestBody));
            req.setTimeout(120000); // 2-minute timeout
            
            // Send the request
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            // Process the response
            if (res.getStatusCode() == 200) {
                // Parse the JSON response
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                
                // Extract the agent response
                String agentResponse = '';
                
                if (responseMap.containsKey('messages') && responseMap.get('messages') != null) {
                    List<Object> messages = (List<Object>) responseMap.get('messages');
                    if (!messages.isEmpty()) {
                        Map<String, Object> firstMessage = (Map<String, Object>) messages[0];
                        agentResponse = (String) firstMessage.get('message');
                    }
                }
                
                if (String.isBlank(agentResponse)) {
                    agentResponse = 'No response from agent';
                }
                
                // Increment the sequence ID for the next message
                sequenceId++;
                
                // Build the success response
                Map<String, Object> result = buildSuccessResponse('Message sent successfully with alternate URL');
                result.put('agentResponse', agentResponse);
                result.put('nextSequenceId', sequenceId);
                
                return result;
            } else {
                String errorMessage = 'Message sending error with alternate URL: ' + res.getStatusCode() + ' ' + res.getStatus();
                System.debug(errorMessage);
                System.debug('Response: ' + res.getBody());
                
                return buildErrorResponse(errorMessage);
            }
        } catch (Exception e) {
            String errorMessage = 'Exception during message sending with alternate URL: ' + e.getMessage();
            System.debug(errorMessage);
            return buildErrorResponse(errorMessage);
        }
    }
    
    /**
     * Get the status of the current session
     * @return Session status
     */
    @AuraEnabled
    public static Map<String, Object> getSessionStatus() {
        try {
            if (String.isBlank(sessionId)) {
                return buildErrorResponse('No active session');
            }
            
            Map<String, Object> result = buildSuccessResponse('Session status retrieved');
            result.put('sessionId', sessionId);
            result.put('sequenceId', sequenceId);
            result.put('active', !String.isBlank(sessionId));
            
            return result;
        } catch (Exception e) {
            String errorMessage = 'Exception getting session status: ' + e.getMessage();
            System.debug(errorMessage);
            return buildErrorResponse(errorMessage);
        }
    }
    
    /**
     * Helper method to get AgentForce settings
     * @return AgentForce settings from custom metadata
     */
    private static AgentForce_Settings__mdt getSettings() {
        if (cachedSettings == null) {
            // Query settings from custom metadata
            List<AgentForce_Settings__mdt> settingsList = [
                SELECT Server_URL__c, Client_ID__c, Client_Secret__c, Agent_ID__c, Org_ID__c, Is_Enabled__c
                FROM AgentForce_Settings__mdt
                WHERE DeveloperName = 'Default'
                LIMIT 1
            ];
            
            if (settingsList.isEmpty()) {
                throw new AuraHandledException('AgentForce settings not found. Please configure the settings in custom metadata.');
            }
            
            cachedSettings = settingsList[0];
        }
        
        return cachedSettings;
    }
    
    /**
     * Generate a random UUID
     * @return Random UUID string
     */
    private static String generateRandomUUID() {
        return EncodingUtil.convertToHex(Crypto.generateAESKey(128)).substring(0, 32);
    }
    
    /**
     * Build a success response
     * @param message Success message
     * @return Map with success response
     */
    private static Map<String, Object> buildSuccessResponse(String message) {
        Map<String, Object> response = new Map<String, Object>();
        response.put('success', true);
        response.put('message', message);
        return response;
    }
    
    /**
     * Build an error response
     * @param error Error message
     * @return Map with error response
     */
    private static Map<String, Object> buildErrorResponse(String error) {
        Map<String, Object> response = new Map<String, Object>();
        response.put('success', false);
        response.put('error', error);
        return response;
    }
}