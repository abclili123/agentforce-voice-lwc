# Salesforce Voice Assistant for AgentForce

A Lightning Web Component (LWC) that enables natural voice interaction with Salesforce data through AgentForce, leveraging OpenAI's Whisper for speech-to-text and TTS for synthesized voice responses.

## Overview

This component creates a seamless voice interface in Salesforce:

1. **Speech-to-Text**: Captures user's voice through the microphone and transcribes it using OpenAI's Whisper API
2. **AgentForce Integration**: Sends the transcribed text to AgentForce for intelligent processing
3. **Text-to-Speech**: Converts AgentForce's response back to speech using OpenAI's TTS API

## Prerequisites

Before deploying this component, ensure you have:

- An active Salesforce org with API access
- OpenAI API key with credit balance
- AgentForce configured in your org
- Salesforce CLI (v2) installed locally
- The following information ready:
  - OpenAI API Key
  - Your Salesforce Org URL (e.g., `storm-41153b85fca0d8.my.salesforce.com`)
  - Client ID and Client Secret for OAuth
  - AgentForce Agent ID (found in Agent Builder URL when editing agent)
  - Org ID

## Setup Instructions

### 1. Configure Trusted URLs in Salesforce

First, you need to add OpenAI's API domain as a trusted URL and allow microphone access:

1. In Salesforce Setup, navigate to **Security** > **CORS**
2. Add `https://api.openai.com` to the allowed origins

3. Go to **Security** > **Session Settings**
4. Under Browser Feature Permissions, ensure you have selected "Trusted URLs Only" for both Camera and Microphone access:

![Browser Feature Permissions](setup_screenshots/browser_permissions.png)

5. Navigate to **Setup** > **Security** > **Trusted URLs**
6. Click "New" to add a new trusted URL
7. Enter the following:
   - Name: OpenAI
   - URL: https://api.openai.com
8. Save the trusted URL

9. Click on your newly created trusted URL to view details
10. Ensure both "camera" and "microphone" permissions are enabled:

![Trusted URL Details](setup_screenshots/trusted_url_details.png)

### 2. Configure Named Credentials

1. Navigate to **Setup** > **Security** > **Named Credentials**
2. Create a new Named Credential as shown:

![Named Credentials](setup_screenshots/named_credential.png)

3. Fill in the following details:
   - Label: OpenAI
   - Name: OpenAI
   - URL: https://api.openai.com
   - Authentication Protocol: No Authentication
   - Save

4. Navigate to **Setup** > **Security** > **Remote Site Settings**
5. Verify that `https://api.openai.com` is added to your Remote Site Settings

### 3. Deploy the Component

1. Clone or download this repository to your local machine
2. Open a terminal and navigate to the downloaded directory

3. Connect to your Salesforce org by creating an alias:
   ```bash
   sf org login web -a myOrgAlias
   ```

4. Deploy the component to your org:
   ```bash
   sf project deploy start -o myOrgAlias
   ```

### 4. Configure Settings

1. After deployment, navigate to the settings page:
   ```
   https://YOUR_ORG_URL.my.salesforce.com/apex/VoiceAssistantSettings
   ```

2. Fill in your OpenAI and AgentForce settings:
   - **OpenAI Settings**:
     - API Key: Your OpenAI API key
     - Default Model: `gpt-3.5-turbo` (or any other available model)
     - Default Voice: `alloy` (or any other available voice)
     - Enabled: Checked

   - **AgentForce Settings**:
     - Server URL: Your Salesforce org domain (e.g., `storm-41153b85fca0d8.my.salesforce.com`)
     - Client ID: Your Connected App's Client ID
     - Client Secret: Your Connected App's Client Secret
     - Agent ID: Your AgentForce Agent ID
     - Org ID: Your Salesforce Org ID
     - Enabled: Checked

3. Click the "Test OpenAI" and "Test AgentForce" buttons to verify connectivity
4. Click "Save" to store your settings

### 5. Add the Component to a Lightning Page

1. Navigate to any Lightning page you wish to add the component to
2. Edit the page in Lightning App Builder
3. Find the "Voice Assistant" component in the component list
4. Drag and drop it onto your page
5. Save and activate the page

## First Use

When using the component for the first time:

1. Your browser will prompt for microphone access - allow it
2. Click the "Hold to Talk" button and speak your query
3. The component will:
   - Transcribe your speech using OpenAI Whisper
   - Send the transcribed text to AgentForce
   - Receive a response from AgentForce
   - Convert the response to speech using OpenAI TTS
   - Play the audio response

## Troubleshooting

- **Microphone not working**: Ensure you've granted microphone permissions in your browser
- **"Refused to load media"**: This is due to Content Security Policy. The component has been updated to handle this by converting base64 audio to Blob URLs
- **No response from AgentForce**: Verify that your AgentForce settings are correct and that your agent is properly configured
- **Audio not playing**: Check that your browser's audio is enabled and not muted
- **Deployment failures**: Ensure you're using the correct Salesforce CLI commands and have necessary permissions

## Technical Details

This component uses:

- **Speech-to-Text**: OpenAI's Whisper model for accurate voice transcription
- **AI Processing**: AgentForce for intelligent query processing
- **Text-to-Speech**: OpenAI's TTS service for natural-sounding voice responses
- **Apex Controllers**: For secure server-side processing
- **Lightning Web Components**: For the browser UI
- **Blob URLs**: To work around Content Security Policy restrictions for audio playback

## Security Notes

- No API keys or credentials are hardcoded in the application
- All sensitive data is stored securely in Salesforce Custom Metadata
- The component uses browser-native APIs for audio capture and playback
- Content Security Policy compliant media handling

## License

[Include license information here]
