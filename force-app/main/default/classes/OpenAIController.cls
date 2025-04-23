/**
 * OpenAIController
 * Handles integration with OpenAI APIs for the Voice Assistant
 */
public with sharing class OpenAIController {
    
    // Cache for settings to avoid multiple queries
    private static OpenAI_Settings__mdt cachedSettings;
    
    /**
     * Get the OpenAI API key securely for client-side API calls
     * This should only be used for authenticated, secured components
     * @return The OpenAI API key
     */
    @AuraEnabled
    public static String getSecureApiKey() {
        try {
            OpenAI_Settings__mdt settings = getSettings();
            if (!settings.Is_Enabled__c) {
                throw new AuraHandledException('OpenAI API integration is disabled');
            }
            return settings.API_Key__c;
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving API key: ' + e.getMessage());
        }
    }
    
    /**
     * Get OpenAI API settings from custom metadata
     * @return Map of settings
     */
    @AuraEnabled
    public static Map<String, Object> getOpenAISettings() {
        try {
            // Get settings from custom metadata
            OpenAI_Settings__mdt settings = getSettings();
            
            // Return as a map for LWC
            Map<String, Object> settingsMap = new Map<String, Object>();
            // Mask API key for security
            settingsMap.put('apiKey', '******');
            settingsMap.put('defaultModel', settings.Default_Model__c);
            settingsMap.put('defaultVoice', settings.Default_Voice__c);
            settingsMap.put('isEnabled', settings.Is_Enabled__c);
            
            return settingsMap;
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching OpenAI settings: ' + e.getMessage());
        }
    }
    
    /**
     * Process audio data with OpenAI's Whisper API
     * @param audioBase64 Base64-encoded audio data
     * @return Transcription result
     */
    @AuraEnabled
    public static Map<String, String> processAudio(String audioBase64) {
        System.debug('Starting audio processing with Whisper API');
        
        try {
            // Get settings
            OpenAI_Settings__mdt settings = getSettings();
            
            // Check if API is enabled
            if (!settings.Is_Enabled__c) {
                throw new AuraHandledException('OpenAI API integration is disabled');
            }
            
            // Parse the base64 data
            String base64Data = audioBase64;
            
            // Handle both data URI format and raw base64
            if (base64Data.startsWith('data:')) {
                // Format is likely data:audio/webm;base64,<actualdata> or data:audio/mp3;base64,<actualdata>
                base64Data = base64Data.substringAfter('base64,');
            } else if (base64Data.contains(',')) {
                // Alternative format with just a comma
                base64Data = base64Data.substringAfter(',');
            }
            
            System.debug('Base64 data length: ' + base64Data.length());
            
            // Convert base64 to blob
            Blob audioBlob = EncodingUtil.base64Decode(base64Data);
            System.debug('Audio blob size: ' + audioBlob.size());
            
            // Set up the HTTP request
            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://api.openai.com/v1/audio/transcriptions');
            req.setMethod('POST');
            req.setHeader('Authorization', 'Bearer ' + settings.API_Key__c);
            
            // Create the multipart boundary
            String boundary = '----WebKitFormBoundary' + String.valueOf(System.now().getTime());
            req.setHeader('Content-Type', 'multipart/form-data; boundary=' + boundary);
            
            // Build the multipart form
            String body = '';
            
            // Add model parameter
            body += '--' + boundary + '\r\n';
            body += 'Content-Disposition: form-data; name="model"\r\n\r\n';
            body += 'whisper-1\r\n';
            
            // Removed language parameter to enable automatic language detection
            
            // Add response_format parameter
            body += '--' + boundary + '\r\n';
            body += 'Content-Disposition: form-data; name="response_format"\r\n\r\n';
            body += 'json\r\n';
            
            // Add temperature parameter (lower for more accurate transcriptions)
            body += '--' + boundary + '\r\n';
            body += 'Content-Disposition: form-data; name="temperature"\r\n\r\n';
            body += '0.0\r\n';
            
            // Add file parameter
            body += '--' + boundary + '\r\n';
            body += 'Content-Disposition: form-data; name="file"; filename="audio.mp3"\r\n';
            body += 'Content-Type: audio/mpeg\r\n';
            body += 'Content-Transfer-Encoding: base64\r\n\r\n';
            
            // Add base64 encoded audio and closing boundary
            body += EncodingUtil.base64Encode(audioBlob) + '\r\n';
            body += '--' + boundary + '--';
            
            // Set the request body
            req.setBody(body);
            req.setTimeout(120000); // 2-minute timeout
            
            // Send the request
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            System.debug('Response status code: ' + res.getStatusCode());
            System.debug('Response status: ' + res.getStatus());
            
            // Process the response
            if (res.getStatusCode() == 200) {
                // Parse the JSON response
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                
                // Return the transcription
                Map<String, String> result = new Map<String, String>();
                result.put('text', (String) responseMap.get('text'));
                return result;
            } else {
                System.debug('OpenAI API Error: ' + res.getBody());
                throw new AuraHandledException('Error from OpenAI API: ' + res.getStatusCode() + ' ' + res.getStatus() + ' - ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug('Error in processAudio: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            System.debug('Line number: ' + e.getLineNumber());
            System.debug('Type: ' + e.getTypeName());
            
            // Fallback approach (try simpler method)
            try {
                // Get settings again
                OpenAI_Settings__mdt settings = getSettings();
                
                // Re-parse the base64 data
                String fallbackBase64Data = audioBase64;
                if (fallbackBase64Data.startsWith('data:')) {
                    fallbackBase64Data = fallbackBase64Data.substringAfter('base64,');
                } else if (fallbackBase64Data.contains(',')) {
                    fallbackBase64Data = fallbackBase64Data.substringAfter(',');
                }
                
                // Re-convert to blob with smaller size (limit to 25MB)
                Blob fallbackAudioBlob = EncodingUtil.base64Decode(fallbackBase64Data);
                
                // Create a simplified request
                HttpRequest req = new HttpRequest();
                req.setEndpoint('https://api.openai.com/v1/audio/transcriptions');
                req.setMethod('POST');
                req.setHeader('Authorization', 'Bearer ' + settings.API_Key__c);
                
                // Try with simple content-type
                String boundary = '----WhisperApiBoundary' + String.valueOf(System.now().getTime());
                req.setHeader('Content-Type', 'multipart/form-data; boundary=' + boundary);
                
                // Build a minimal body
                String body = '';
                body += '--' + boundary + '\r\n';
                body += 'Content-Disposition: form-data; name="model"\r\n\r\n';
                body += 'whisper-1\r\n';
                
                // Removed language parameter for automatic language detection
                body += '--' + boundary + '\r\n';
                body += 'Content-Disposition: form-data; name="file"; filename="audio.mp3"\r\n';
                body += 'Content-Type: audio/mpeg\r\n\r\n';
                
                // Skip base64 encoding, use direct binary
                String dataBody = EncodingUtil.base64Encode(fallbackAudioBlob);
                
                // Add closing boundary
                body += dataBody + '\r\n--' + boundary + '--';
                
                req.setBody(body);
                req.setTimeout(120000); // 2-minute timeout
                
                // Send the request
                Http http = new Http();
                HttpResponse res = http.send(req);
                
                if (res.getStatusCode() == 200) {
                    // Parse the response
                    Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                    
                    // Return the transcription
                    Map<String, String> result = new Map<String, String>();
                    result.put('text', (String) responseMap.get('text'));
                    return result;
                } else {
                    throw new AuraHandledException('Fallback method failed: ' + res.getStatusCode() + ' ' + res.getStatus());
                }
            } catch (Exception fallbackError) {
                System.debug('Fallback error: ' + fallbackError.getMessage());
                throw new AuraHandledException('Error processing audio: ' + e.getMessage() + ' Fallback error: ' + fallbackError.getMessage());
            }
        }
    }
    
    /**
     * Generate a response using OpenAI's GPT API
     * @param userMessage User's message/query
     * @return AI-generated response
     */
    @AuraEnabled
    public static String generateResponse(String userMessage) {
        try {
            // Get settings
            OpenAI_Settings__mdt settings = getSettings();
            
            // Check if API is enabled
            if (!settings.Is_Enabled__c) {
                throw new AuraHandledException('OpenAI API integration is disabled');
            }
            
            // Set up the HTTP request
            HttpRequest req = new HttpRequest();
            // Direct API endpoint
            req.setEndpoint('https://api.openai.com/v1/chat/completions');
            req.setMethod('POST');
            req.setHeader('Authorization', 'Bearer ' + settings.API_Key__c);
            req.setHeader('Content-Type', 'application/json');
            
            // Build the request body
            Map<String, Object> requestBody = new Map<String, Object>();
            requestBody.put('model', settings.Default_Model__c);
            
            // Create messages array
            List<Map<String, String>> messages = new List<Map<String, String>>();
            
            // System message
            Map<String, String> systemMessage = new Map<String, String>();
            systemMessage.put('role', 'system');
            systemMessage.put('content', 'You are a helpful voice assistant. Keep your responses concise and conversational, suitable for speech.');
            messages.add(systemMessage);
            
            // User message
            Map<String, String> userMsg = new Map<String, String>();
            userMsg.put('role', 'user');
            userMsg.put('content', userMessage);
            messages.add(userMsg);
            
            requestBody.put('messages', messages);
            requestBody.put('max_tokens', 150);
            
            req.setBody(JSON.serialize(requestBody));
            req.setTimeout(30000); // 30-second timeout
            
            // Send the request
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            // Process the response
            if (res.getStatusCode() == 200) {
                // Parse the JSON response
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                
                // Extract the response text
                List<Object> choices = (List<Object>) responseMap.get('choices');
                Map<String, Object> choice = (Map<String, Object>) choices[0];
                Map<String, Object> message = (Map<String, Object>) choice.get('message');
                String responseText = (String) message.get('content');
                
                return responseText;
            } else {
                System.debug('OpenAI API Error: ' + res.getBody());
                throw new AuraHandledException('Error from OpenAI API: ' + res.getStatusCode() + ' ' + res.getStatus());
            }
        } catch (Exception e) {
            System.debug('Error in generateResponse: ' + e.getMessage() + '\n' + e.getStackTraceString());
            throw new AuraHandledException('Error generating response: ' + e.getMessage());
        }
    }
    
    /**
     * Convert text to speech using OpenAI's TTS API
     * @param text Text to convert to speech
     * @param voice Voice to use (e.g., alloy, echo, etc.)
     * @return Base64-encoded audio data
     */
    @AuraEnabled
    public static String textToSpeech(String text, String voice) {
        try {
            // Get settings
            OpenAI_Settings__mdt settings = getSettings();
            
            // Debug the incoming parameters
            System.debug('Text-to-Speech request - Text length: ' + (text != null ? String.valueOf(text.length()) : 'null') + 
                        ', Voice: ' + voice);
            
            // Check if API is enabled
            if (!settings.Is_Enabled__c) {
                throw new AuraHandledException('OpenAI API integration is disabled');
            }
            
            // Use default voice if not specified
            if (String.isBlank(voice)) {
                voice = settings.Default_Voice__c;
            }
            
            // Validate and truncate text if needed (OpenAI has token limits)
            if (String.isBlank(text)) {
                throw new AuraHandledException('Text content cannot be empty');
            }
            
            // OpenAI has a limit, let's keep it reasonable (approx 4000 chars ~ 1000 tokens)
            if (text.length() > 4000) {
                System.debug('Text too long (' + text.length() + ' chars), truncating to 4000 chars');
                text = text.substring(0, 4000);
            }
            
            // Set up the HTTP request
            HttpRequest req = new HttpRequest();
            // Direct API endpoint
            req.setEndpoint('https://api.openai.com/v1/audio/speech');
            req.setMethod('POST');
            req.setHeader('Authorization', 'Bearer ' + settings.API_Key__c);
            req.setHeader('Content-Type', 'application/json');
            
            // Build the request body
            Map<String, Object> requestBody = new Map<String, Object>();
            requestBody.put('model', 'tts-1');
            requestBody.put('voice', voice);
            requestBody.put('input', text);
            // Explicitly set format to mp3 for better browser compatibility
            requestBody.put('response_format', 'mp3');
            
            String requestBodyJson = JSON.serialize(requestBody);
            req.setBody(requestBodyJson);
            req.setTimeout(60000); // 1-minute timeout
            
            // Debug the request
            System.debug('Sending TTS request to OpenAI. Model: tts-1, Voice: ' + voice);
            
            // Send the request
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            // Debug the response status
            System.debug('OpenAI TTS API response status: ' + res.getStatusCode() + ' ' + res.getStatus());
            
            // Process the response
            if (res.getStatusCode() == 200) {
                // Get content type from headers
                String contentType = res.getHeader('Content-Type');
                System.debug('OpenAI TTS response Content-Type: ' + contentType);
                
                // Check response size
                Blob audioBlob = res.getBodyAsBlob();
                System.debug('Received audio blob size: ' + audioBlob.size() + ' bytes');
                
                if (audioBlob.size() == 0) {
                    throw new AuraHandledException('Received empty audio data from OpenAI');
                }
                
                // Convert the binary response to base64 with proper MIME type
                String mimeType = contentType != null ? contentType : 'audio/mp3';
                String base64Audio = 'data:' + mimeType + ';base64,' + EncodingUtil.base64Encode(audioBlob);
                
                System.debug('Successfully generated audio response, length: ' + base64Audio.length() + ' chars');
                return base64Audio;
            } else {
                // Try to parse error response as JSON for better error messages
                String errorBody = res.getBody();
                System.debug('OpenAI API Error: ' + errorBody);
                
                String errorMessage;
                try {
                    Map<String, Object> errorMap = (Map<String, Object>)JSON.deserializeUntyped(errorBody);
                    Map<String, Object> errorDetail = (Map<String, Object>)errorMap.get('error');
                    if (errorDetail != null && errorDetail.containsKey('message')) {
                        errorMessage = 'OpenAI error: ' + (String)errorDetail.get('message');
                    } else {
                        errorMessage = 'Error from OpenAI API: ' + res.getStatusCode() + ' ' + res.getStatus();
                    }
                } catch (Exception jsonEx) {
                    errorMessage = 'Error from OpenAI API: ' + res.getStatusCode() + ' ' + res.getStatus();
                }
                
                throw new AuraHandledException(errorMessage);
            }
        } catch (Exception e) {
            System.debug('Error in textToSpeech: ' + e.getMessage() + '\n' + e.getStackTraceString());
            throw new AuraHandledException('Error generating speech: ' + e.getMessage());
        }
    }
    
    /**
     * Helper method to get OpenAI settings
     * @return OpenAI settings from custom metadata
     */
    private static OpenAI_Settings__mdt getSettings() {
        if (cachedSettings == null) {
            // Query settings from custom metadata
            List<OpenAI_Settings__mdt> settingsList = [
                SELECT API_Key__c, Default_Model__c, Default_Voice__c, Is_Enabled__c
                FROM OpenAI_Settings__mdt
                WHERE DeveloperName = 'Default'
                LIMIT 1
            ];
            
            if (settingsList.isEmpty()) {
                throw new AuraHandledException('OpenAI settings not found. Please configure the settings in custom metadata.');
            }
            
            cachedSettings = settingsList[0];
        }
        
        return cachedSettings;
    }
}