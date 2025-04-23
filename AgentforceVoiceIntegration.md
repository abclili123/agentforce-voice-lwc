# 🎙️ Agentforce Voice LWC Integration

This project allows you to create an interactive voice experience in Salesforce, leveraging OpenAI's APIs for speech processing and AgentForce for intelligent responses.

## 🔗 References
- OpenAI API: [https://platform.openai.com/docs](https://platform.openai.com/docs)
- Salesforce Lightning Design System: [https://www.lightningdesignsystem.com](https://www.lightningdesignsystem.com)
- AgentForce Documentation: [https://help.salesforce.com/s/articleView?id=sf.agent_builder.htm](https://help.salesforce.com/s/articleView?id=sf.agent_builder.htm)

---

## 🧩 Component Objectives

- 🎤 Record voice via microphone
- 🧠 Transcribe voice using `OpenAI Whisper Speech-to-Text` API
- 📡 Send transcribed text to AgentForce
- 🗣️ Convert AgentForce response to audio with `OpenAI Text-to-Speech` API
- 💬 Display exchanged messages in a SLDS-compliant bubble UI

---

## 📁 Project Structure

```
force-app/
└── main/
    └── default/
        ├── lwc/
        │   ├── voiceAssistant/
        │   │   ├── voiceAssistant.html
        │   │   ├── voiceAssistant.js
        │   │   ├── voiceAssistant.css
        │   │   └── voiceAssistant.js-meta.xml
        │   └── audioProcessor/
        │       ├── audioProcessor.js
        │       └── audioProcessor.js-meta.xml
        ├── classes/
        │   ├── AgentForceController.cls
        │   ├── AgentforceService.cls
        │   ├── OpenAIController.cls
        │   └── VoiceAssistantSettingsController.cls
        ├── pages/
        │   └── VoiceAssistantSettings.page
        └── customMetadata/
            ├── AgentForce_Settings__mdt.Default.md-meta.xml
            └── OpenAI_Settings__mdt.Default.md-meta.xml
```

---

## 💻 Voice Assistant Components

### Voice Assistant LWC
The main component that provides the user interface for voice interaction:
- Recording voice input
- Displaying conversation history
- Playing back spoken responses

### Audio Processor
Helper module for handling audio operations:
- Converting between different audio formats
- Optimizing audio for the Whisper API
- Handling audio playback with browser security constraints

---

## ⚙️ Apex Controllers

### OpenAIController
Handles all interactions with OpenAI APIs:
- Speech-to-text using Whisper API
- Text-to-speech synthesis
- Fallback text completion if needed

### AgentForceController & AgentforceService
Manage communication with AgentForce:
- Authentication with OAuth
- Session management
- Message exchange with AgentForce agents

### VoiceAssistantSettingsController
Manages configuration settings:
- Reading/writing custom metadata records
- Testing API connections
- Storing API keys securely

---

## 🔐 Security Considerations

### Content Security Policy (CSP)
The component uses Blob URLs to play audio responses, avoiding direct base64 data URLs which would be blocked by Salesforce's CSP.

### Credential Storage
All sensitive credentials are stored in Custom Metadata Types, not hardcoded in the application:
- OpenAI API Key
- AgentForce authentication details
- Endpoint URLs

### Browser Permissions
The component requires explicit permission for microphone access, which must be configured in Salesforce's Trusted URLs settings.

---

## 🚀 Deployment Process

1. Configure Salesforce security settings (CORS, Trusted URLs, Remote Site Settings)
2. Deploy the LWC components and Apex classes
3. Configure Custom Metadata via the settings page
4. Add the component to a Lightning page
5. Test the voice interaction flow

---

## 🧪 Technical Workflow

1. User clicks "Hold to Talk" button
2. Browser microphone records audio
3. Audio is processed and sent to OpenAI Whisper for transcription
4. Transcribed text is displayed and sent to AgentForce
5. AgentForce processes the query and returns a response
6. Response is sent to OpenAI TTS for voice synthesis
7. Audio response is played back while displaying the text

---

**Note**: For production deployments, ensure you have adequate OpenAI API credits as the voice processing can consume significant resources.
