/**
 * VoiceAssistantSettingsController
 * Controller for the Voice Assistant Settings Visualforce page
 */
public with sharing class VoiceAssistantSettingsController {
    
    // Properties for OpenAI settings
    public String openAIApiKey { get; set; }
    public String openAIDefaultModel { get; set; }
    public String openAIDefaultVoice { get; set; }
    public Boolean openAIIsEnabled { get; set; }
    
    // Properties for AgentForce settings
    public String agentForceServerUrl { get; set; }
    public String agentForceClientId { get; set; }
    public String agentForceClientSecret { get; set; }
    public String agentForceAgentId { get; set; }
    public String agentForceOrgId { get; set; }
    public Boolean agentForceIsEnabled { get; set; }
    
    // Available options for voice and model
    public List<SelectOption> voiceOptions { get; set; }
    public List<SelectOption> modelOptions { get; set; }
    
    // Messages for UI
    public String message { get; set; }
    public String messageType { get; set; }
    
    // Constructor
    public VoiceAssistantSettingsController() {
        loadSettings();
        initializeOptions();
    }
    
    // Load settings from Custom Metadata
    private void loadSettings() {
        try {
            // Load OpenAI settings
            List<OpenAI_Settings__mdt> openAISettingsList = [
                SELECT API_Key__c, Default_Model__c, Default_Voice__c, Is_Enabled__c
                FROM OpenAI_Settings__mdt
                WHERE DeveloperName = 'Default'
                LIMIT 1
            ];
            
            if (!openAISettingsList.isEmpty()) {
                OpenAI_Settings__mdt openAISettings = openAISettingsList[0];
                openAIApiKey = openAISettings.API_Key__c;
                openAIDefaultModel = openAISettings.Default_Model__c;
                openAIDefaultVoice = openAISettings.Default_Voice__c;
                openAIIsEnabled = openAISettings.Is_Enabled__c;
            } else {
                // Default values if no settings found
                openAIApiKey = '';
                openAIDefaultModel = 'gpt-4o';
                openAIDefaultVoice = 'alloy';
                openAIIsEnabled = true;
            }
            
            // Load AgentForce settings
            List<AgentForce_Settings__mdt> agentForceSettingsList = [
                SELECT Server_URL__c, Client_ID__c, Client_Secret__c, Agent_ID__c, Org_ID__c, Is_Enabled__c
                FROM AgentForce_Settings__mdt
                WHERE DeveloperName = 'Default'
                LIMIT 1
            ];
            
            if (!agentForceSettingsList.isEmpty()) {
                AgentForce_Settings__mdt agentForceSettings = agentForceSettingsList[0];
                agentForceServerUrl = agentForceSettings.Server_URL__c;
                agentForceClientId = agentForceSettings.Client_ID__c;
                agentForceClientSecret = agentForceSettings.Client_Secret__c;
                agentForceAgentId = agentForceSettings.Agent_ID__c;
                agentForceOrgId = agentForceSettings.Org_ID__c;
                agentForceIsEnabled = agentForceSettings.Is_Enabled__c;
            } else {
                // Default values if no settings found
                agentForceServerUrl = 'login.salesforce.com';
                agentForceClientId = '';
                agentForceClientSecret = '';
                agentForceAgentId = '';
                agentForceOrgId = '';
                agentForceIsEnabled = false;
            }
        } catch (Exception e) {
            message = 'Error loading settings: ' + e.getMessage();
            messageType = 'error';
            System.debug('Error loading settings: ' + e.getMessage() + '\n' + e.getStackTraceString());
        }
    }
    
    // Initialize select options
    private void initializeOptions() {
        // Initialize voice options
        voiceOptions = new List<SelectOption>();
        voiceOptions.add(new SelectOption('alloy', 'Alloy'));
        voiceOptions.add(new SelectOption('echo', 'Echo'));
        voiceOptions.add(new SelectOption('fable', 'Fable'));
        voiceOptions.add(new SelectOption('onyx', 'Onyx'));
        voiceOptions.add(new SelectOption('nova', 'Nova'));
        voiceOptions.add(new SelectOption('shimmer', 'Shimmer'));
        
        // Initialize model options
        modelOptions = new List<SelectOption>();
        modelOptions.add(new SelectOption('gpt-4o', 'GPT-4o'));
        modelOptions.add(new SelectOption('gpt-4', 'GPT-4'));
        modelOptions.add(new SelectOption('gpt-3.5-turbo', 'GPT-3.5 Turbo'));
    }
    
    // Save settings to Custom Metadata
    public PageReference saveSettings() {
        Savepoint sp = Database.setSavepoint();
        try {
            // Create metadata deployment container
            Metadata.DeployContainer mdContainer = new Metadata.DeployContainer();
            
            // Update OpenAI settings
            Metadata.CustomMetadata openAIMetadata = new Metadata.CustomMetadata();
            openAIMetadata.fullName = 'OpenAI_Settings__mdt.Default';
            openAIMetadata.label = 'Default';
            
            // Add fields
            // OpenAI settings fields
            addMetadataField(openAIMetadata, 'API_Key__c', openAIApiKey);
            addMetadataField(openAIMetadata, 'Default_Model__c', openAIDefaultModel);
            addMetadataField(openAIMetadata, 'Default_Voice__c', openAIDefaultVoice);
            addMetadataField(openAIMetadata, 'Is_Enabled__c', openAIIsEnabled);
            
            // Add to container
            mdContainer.addMetadata(openAIMetadata);
            
            // Update AgentForce settings
            Metadata.CustomMetadata agentForceMetadata = new Metadata.CustomMetadata();
            agentForceMetadata.fullName = 'AgentForce_Settings__mdt.Default';
            agentForceMetadata.label = 'Default';
            
            // Add fields
            // AgentForce settings fields
            addMetadataField(agentForceMetadata, 'Server_URL__c', agentForceServerUrl);
            addMetadataField(agentForceMetadata, 'Client_ID__c', agentForceClientId);
            addMetadataField(agentForceMetadata, 'Client_Secret__c', agentForceClientSecret);
            addMetadataField(agentForceMetadata, 'Agent_ID__c', agentForceAgentId);
            addMetadataField(agentForceMetadata, 'Org_ID__c', agentForceOrgId);
            addMetadataField(agentForceMetadata, 'Is_Enabled__c', agentForceIsEnabled);
            
            // Add to container
            mdContainer.addMetadata(agentForceMetadata);
            
            // Deploy the metadata
            if (!Test.isRunningTest()) {
                Id deployJobId = Metadata.Operations.enqueueDeployment(mdContainer, null);
                message = 'Settings saved. Deployment job ID: ' + deployJobId + 
                          '. Changes take a few seconds to apply; please refresh page to see updated values.';
                messageType = 'success';
            } else {
                message = 'Settings saved (test mode). Please refresh page to see updated values.';
                messageType = 'success';
            }
            
            return null;
        } catch (Exception e) {
            Database.rollback(sp);
            message = 'Error saving settings: ' + e.getMessage();
            messageType = 'error';
            System.debug('Error saving settings: ' + e.getMessage() + '\n' + e.getStackTraceString());
            return null;
        }
    }
    
    // Cancel and go back
    public PageReference cancel() {
        // Go back to home page
        return new PageReference('/');
    }
    
    // Test connection to OpenAI
    public PageReference testOpenAIConnection() {
        try {
            // Set up the HTTP request
            HttpRequest req = new HttpRequest();
            // Use direct URL instead of Named Credential
            req.setEndpoint('https://api.openai.com/v1/models');
            req.setMethod('GET');
            req.setHeader('Authorization', 'Bearer ' + openAIApiKey);
            req.setTimeout(10000); // 10-second timeout
            
            // Send the request
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            // Process the response
            if (res.getStatusCode() == 200) {
                message = 'Successfully connected to OpenAI API!';
                messageType = 'success';
            } else {
                message = 'Failed to connect to OpenAI API: ' + res.getStatusCode() + ' ' + res.getStatus();
                messageType = 'error';
            }
            
            return null;
        } catch (Exception e) {
            message = 'Error testing OpenAI connection: ' + e.getMessage();
            messageType = 'error';
            return null;
        }
    }
    
    // Test connection to AgentForce
    public PageReference testAgentForceConnection() {
        try {
            // Build the token URL - ensure it's a direct URL, not a named credential
            String tokenUrl = 'https://' + agentForceServerUrl + '/services/oauth2/token';
            
            // Set up the HTTP request
            HttpRequest req = new HttpRequest();
            req.setEndpoint(tokenUrl);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            
            // Build the request body
            String body = 'grant_type=client_credentials' +
                          '&client_id=' + agentForceClientId +
                          '&client_secret=' + agentForceClientSecret;
            
            req.setBody(body);
            req.setTimeout(10000); // 10-second timeout
            
            // Send the request
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            // Process the response
            if (res.getStatusCode() == 200) {
                message = 'Successfully connected to AgentForce API!';
                messageType = 'success';
            } else {
                message = 'Failed to connect to AgentForce API: ' + res.getStatusCode() + ' ' + res.getStatus();
                messageType = 'error';
            }
            
            return null;
        } catch (Exception e) {
            message = 'Error testing AgentForce connection: ' + e.getMessage();
            messageType = 'error';
            return null;
        }
    }
    
    // Helper method to add a field to the metadata; value type must match field type
    private void addMetadataField(Metadata.CustomMetadata metadata, String fieldName, Object value) {
        if (metadata.values == null) {
            metadata.values = new List<Metadata.CustomMetadataValue>();
        }
        Metadata.CustomMetadataValue customField = new Metadata.CustomMetadataValue();
        customField.field = fieldName;
        customField.value = value;
        metadata.values.add(customField);
    }
}