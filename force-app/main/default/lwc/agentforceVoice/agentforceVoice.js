import { LightningElement, track } from 'lwc';
import getAgentforceResponse from '@salesforce/apex/AgentforceService.getResponse';

export default class AgentforceVoice extends LightningElement {
    @track isRecording = false;
    @track messages = [];
    recognition;

    connectedCallback() {
        const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
        if (SpeechRecognition) {
            this.recognition = new SpeechRecognition();
            this.recognition.lang = 'fr-FR';
            this.recognition.continuous = false;
            this.recognition.interimResults = false;

            this.recognition.onresult = (event) => {
                const transcript = event.results[0][0].transcript;
                this.messages = [...this.messages, { id: Date.now(), text: transcript, sender: 'user' }];
                this.callAgentforce(transcript);
            };

            this.recognition.onerror = (event) => {
                console.error('Speech recognition error:', event.error);
            };
        } else {
            console.error('SpeechRecognition API not supported in this browser.');
        }
    }

    handleToggleRecording() {
        if (this.isRecording) {
            this.recognition.stop();
        } else {
            this.recognition.start();
        }
        this.isRecording = !this.isRecording;
    }

    async callAgentforce(transcript) {
        try {
            const response = await getAgentforceResponse({ userInput: transcript });
            this.messages = [...this.messages, { id: Date.now(), text: response, sender: 'agent' }];
            this.textToSpeech(response);
        } catch (error) {
            console.error('Error calling Agentforce:', error);
        }
    }

    async textToSpeech(text) {
        try {
            const response = await fetch('https://api.openai.com/v1/audio/speech', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer YOUR_OPENAI_API_KEY`
                },
                body: JSON.stringify({
                    model: 'tts-1',
                    input: text,
                    voice: 'alloy'
                })
            });

            if (response.ok) {
                const audioBlob = await response.blob();
                const audioUrl = URL.createObjectURL(audioBlob);
                const audio = new Audio(audioUrl);
                audio.play();
            } else {
                console.error('Text-to-Speech API error:', response.statusText);
            }
        } catch (error) {
            console.error('Error during text-to-speech:', error);
        }
    }
    get buttonLabel() {
        return this.isRecording ? 'Arrêter' : 'Parler';
    }

    get buttonVariant() {
        return this.isRecording ? 'destructive' : 'brand';
    }

    get formattedMessages() {
        return this.messages.map(msg => ({ ...msg, className: msg.sender === 'user' ? 'user-bubble' : 'agent-bubble' }));
    }
}
