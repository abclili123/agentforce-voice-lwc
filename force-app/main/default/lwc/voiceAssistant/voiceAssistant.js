import { LightningElement, track, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// Import Apex methods
import getOpenAISettings from '@salesforce/apex/OpenAIController.getOpenAISettings';
import getAgentForceSettings from '@salesforce/apex/AgentForceController.getAgentForceSettings';
import generateResponse from '@salesforce/apex/OpenAIController.generateResponse';
import textToSpeech from '@salesforce/apex/OpenAIController.textToSpeech';
import completeAgentForceConversation from '@salesforce/apex/AgentForceController.completeConversation';
import processAudio from '@salesforce/apex/OpenAIController.processAudio';
import getSecureApiKey from '@salesforce/apex/OpenAIController.getSecureApiKey';
import CHATTERBOX_LOGO from '@salesforce/resourceUrl/ChatterboxLogo';

export default class VoiceAssistant extends LightningElement {
    @api recordId;
    @track isRecording = false;
    @track voice = 'alloy';
    @track messages = [];
    @track status = 'Ready';
    @track statusClass = '';
    @track isLoading = true;
    @track error = null;
    @track isCollapsed = true;
    @track chatInput = '';

    avatarUrl = CHATTERBOX_LOGO;

    // ability to collapse component
    get collapseIcon() {
        return this.isCollapsed ? 'utility:chevrondown' : 'utility:chevronup';
    }

    toggleCollapse() {
        this.isCollapsed = !this.isCollapsed;
    }

    lastHtmlMessageId = null;
    
    // Audio processing
    mediaRecorder = null;
    audioContext = null;
    audioStream = null;
    audioChunks = [];
    
    // Settings
    openAISettings;
    agentForceSettings;
    
    /**
     * Convert base64 string to Blob object
     */
    base64ToBlob(base64, mimeType) {
        // Remove data URI scheme if present
        if (base64.startsWith('data:')) {
            base64 = base64.split(',')[1];
        }
        
        const byteCharacters = atob(base64);
        const byteArrays = [];
        
        for (let offset = 0; offset < byteCharacters.length; offset += 512) {
            const slice = byteCharacters.slice(offset, offset + 512);
            
            const byteNumbers = new Array(slice.length);
            for (let i = 0; i < slice.length; i++) {
                byteNumbers[i] = slice.charCodeAt(i);
            }
            
            const byteArray = new Uint8Array(byteNumbers);
            byteArrays.push(byteArray);
        }
        
        return new Blob(byteArrays, {type: mimeType});
    }

    /**
     * Process audio data client-side by calling OpenAI API directly
     */
    async processAudioClientSide(audioBase64) {
        try {
            // Get API key securely from the server
            const apiKey = await getSecureApiKey();
            
            // Determine MIME type from base64 prefix or default to mp3
            let mimeType = 'audio/mp3';
            if (audioBase64.startsWith('data:')) {
                const mediaType = audioBase64.split(',')[0].split(':')[1].split(';')[0];
                if (mediaType) {
                    mimeType = mediaType;
                }
            }
            console.log('Using MIME type:', mimeType);
            
            // Convert base64 to blob
            const base64Data = audioBase64.split(',')[1] || audioBase64;
            const audioBlob = this.base64ToBlob(base64Data, mimeType);
            console.log(`Converted to blob: size=${audioBlob.size} bytes`);
            
            if (audioBlob.size > 25 * 1024 * 1024) {
                throw new Error('Audio file is too large. Maximum size is 25MB.');
            }
            
            // Create FormData object for multipart/form-data request
            const formData = new FormData();
            formData.append('model', 'whisper-1');
            formData.append('file', audioBlob, 'audio.mp3'); // File name with mp3 extension regardless of actual format
            // Removed language parameter to enable automatic language detection
            formData.append('response_format', 'json');
            formData.append('temperature', '0.0');
            
            console.log('Sending direct request to OpenAI API...');
            
            // Send the request directly to OpenAI API
            const response = await fetch('https://api.openai.com/v1/audio/transcriptions', {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${apiKey}`
                },
                body: formData
            });
            
            if (!response.ok) {
                const errorText = await response.text();
                console.error('OpenAI API error:', errorText);
                throw new Error(`OpenAI API error: ${response.status} ${response.statusText}`);
            }
            
            const responseData = await response.json();
            console.log('Transcription received:', responseData);
            
            // Return in the same format as the Apex method would
            return { text: responseData.text };
        } catch (error) {
            console.error('Error in client-side audio processing:', error);
            throw error;
        }
    }
    
    // Voice options for the combobox
    get voiceOptions() {
        return [
            { label: 'Alloy', value: 'alloy' },
            { label: 'Echo', value: 'echo' },
            { label: 'Fable', value: 'fable' },
            { label: 'Onyx', value: 'onyx' },
            { label: 'Nova', value: 'nova' },
            { label: 'Shimmer', value: 'shimmer' }
        ];
    }
    
    // Status light class
    get statusLightClass() {
        return `status-light ${this.statusClass}`;
    }
    
    connectedCallback() {
        this.loadSettings();
        this.addWelcomeMessage();
        // Add global event listeners for keyboard shortcuts
        // window.addEventListener('keydown', this.handleKeyDown.bind(this));
        // window.addEventListener('keyup', this.handleKeyUp.bind(this));
    }
    
    disconnectedCallback() {
        // Clean up event listeners
        // window.removeEventListener('keydown', this.handleKeyDown.bind(this));
        // window.removeEventListener('keyup', this.handleKeyUp.bind(this));
        // Clean up media resources
        this.releaseMediaResources();
    }
    
    releaseMediaResources() {
        if (this.mediaRecorder && this.mediaRecorder.state !== 'inactive') {
            try {
                this.mediaRecorder.stop();
            } catch (e) {
                console.error('Error stopping media recorder:', e);
            }
        }
        
        if (this.audioStream) {
            this.audioStream.getTracks().forEach(track => {
                try {
                    track.stop();
                } catch (e) {
                    console.error('Error stopping audio track:', e);
                }
            });
            this.audioStream = null;
        }
        
        if (this.audioContext) {
            try {
                if (this.audioContext.state !== 'closed') {
                    this.audioContext.close();
                }
            } catch (e) {
                console.error('Error closing audio context:', e);
            }
            this.audioContext = null;
        }
    }
    
    async loadSettings() {
        try {
            // Load settings from custom metadata
            this.openAISettings = await getOpenAISettings();
            this.agentForceSettings = await getAgentForceSettings();
            this.isLoading = false;
            console.log('Settings loaded:', this.openAISettings, this.agentForceSettings);
        } catch (error) {
            this.error = error.message || 'Failed to load settings';
            this.isLoading = false;
            this.showToast('Error loading settings', this.error, 'error');
        }
    }
    
    addWelcomeMessage() {
        this.messages.push({
            id: 'welcome',
            content: 'Thank you for chatting with New York Life. Hello! I\'m glad to assist you today. How may I help you?',
            sender: 'assistant',
            timestamp: new Date().toISOString(),
            cssClass: 'message assistant'
        });
    }
    
    async checkMicrophonePermission() {
        try {
            // Query device permissions
            const permissionStatus = await navigator.permissions.query({name: 'microphone'})
                .catch(error => {
                    console.warn("Permission API not supported, will try direct access", error);
                    return { state: 'unknown' };
                });
            
            console.log("Permission status:", permissionStatus.state);
            
            // If permission is already denied, show permission modal or toast
            if (permissionStatus.state === 'denied') {
                this.showToast('Microphone Access Required', 'Please allow microphone access in your browser settings to use the voice assistant.', 'warning');
                return false;
            }
            
            // If we're unsure about permission, try to access the microphone
            if (permissionStatus.state === 'unknown' || permissionStatus.state === 'prompt') {
                try {
                    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
                    // If we get here, we have microphone access
                    console.log("Successfully accessed microphone");
                    // Close the test stream
                    stream.getTracks().forEach(track => track.stop());
                    return true;
                } catch (error) {
                    console.error("Failed microphone access test:", error);
                    this.showToast('Microphone Access Required', 'Please allow microphone access in your browser settings to use the voice assistant.', 'warning');
                    return false;
                }
            }
            
            return permissionStatus.state === 'granted';
        } catch (error) {
            console.error("Error checking microphone permission:", error);
            this.showToast('Microphone Access Error', 'There was an error checking microphone permissions.', 'error');
            return false;
        }
    }
    
    // RECORDING METHODS
    async initAudioRecording() {
        if (!this.audioContext) {
            this.audioContext = new (window.AudioContext || window.webkitAudioContext)();
        }
        
        // Request microphone access
        try {
            // Use lower quality audio for better compatibility with Whisper
            this.audioStream = await navigator.mediaDevices.getUserMedia({ 
                audio: {
                    echoCancellation: true,
                    noiseSuppression: true,
                    autoGainControl: true,
                    channelCount: 1, // Mono audio (simpler than stereo)
                    sampleRate: 16000 // Lower sample rate (16kHz is good for speech)
                } 
            });
            
            // Reset chunks array
            this.audioChunks = [];
            
            // Create MediaRecorder with optimal settings for Whisper
            const options = {};
            
            // Prioritize formats in order of Whisper compatibility
            if (MediaRecorder.isTypeSupported('audio/mp3')) {
                options.mimeType = 'audio/mp3';
            } else if (MediaRecorder.isTypeSupported('audio/mpeg')) {
                options.mimeType = 'audio/mpeg';
            } else if (MediaRecorder.isTypeSupported('audio/webm;codecs=opus')) {
                options.mimeType = 'audio/webm;codecs=opus';
            }
            
            // Set bitrate to lower quality but still clear enough for speech
            this.mediaRecorder = new MediaRecorder(this.audioStream, {
                ...options,
                audioBitsPerSecond: 64000 // 64kbps is enough for speech
            });
            
            console.log('Using audio format:', this.mediaRecorder.mimeType || 'browser default');
            
            // Set up event handlers
            this.mediaRecorder.ondataavailable = event => {
                if (event.data.size > 0) {
                    this.audioChunks.push(event.data);
                }
            };
            
            // Set a maximum recording duration (30 seconds) for Whisper compatibility
            this.maxRecordingDuration = 30000; // 30 seconds
            
            console.log('Audio recording initialized with optimized settings for Whisper');
            return true;
        } catch (error) {
            console.error('Error initializing audio recording:', error);
            throw error;
        }
    }
    
    async handleHoldToTalkStart() {
        const hasPermission = await this.checkMicrophonePermission();
        if (hasPermission) {
            this.startRecording();
        }
    }
    
    handleHoldToTalkEnd() {
        if (this.isRecording) {
            this.stopRecording();
        }
    }
    
    async startRecording() {
        if (this.isRecording) {
            console.log("Already recording, ignoring startRecording request");
            return;
        }
        
        try {
            this.isRecording = true;
            this.updateStatus('Initializing microphone...', 'processing');
            
            // Initialize audio recording if not already done
            await this.initAudioRecording();
            
            // Start the recorder
            this.mediaRecorder.start(100); // collect in 100ms chunks
            console.log('MediaRecorder started successfully');
            
            // Set a timer to stop recording after the maximum duration
            this.recordingTimer = setTimeout(() => {
                if (this.isRecording) {
                    console.log(`Maximum recording duration of ${this.maxRecordingDuration/1000}s reached, stopping automatically`);
                    this.stopRecording();
                }
            }, this.maxRecordingDuration);
            
            this.updateStatus('Listening', 'listening');
        } catch (error) {
            console.error('Error starting recording:', error);
            this.isRecording = false;
            this.updateStatus('Error', 'error');
            
            // Display error with more helpful message
            let errorMessage = 'Failed to start recording.';
            
            if (error.name === 'NotAllowedError' || error.message.includes('denied') || error.message.includes('permission')) {
                errorMessage = 'Microphone access denied. Please check your browser permissions and make sure microphone access is allowed for this site.';
            } else if (error.name === 'NotFoundError' || error.message.includes('not found')) {
                errorMessage = 'No microphone found. Please connect a microphone and try again.';
            }
            
            this.showToast('Recording Error', errorMessage, 'error');
        }
    }
    
    async stopRecording() {
        if (!this.isRecording) {
            console.log("Not recording, ignoring stopRecording request");
            return;
        }
        
        try {
            this.isRecording = false;
            this.updateStatus('Processing', 'processing');
            
            // Clear recording timeout if it exists
            if (this.recordingTimer) {
                clearTimeout(this.recordingTimer);
                this.recordingTimer = null;
            }
            
            // Return a promise to get the recording data
            const audioBase64 = await new Promise((resolve, reject) => {
                if (!this.mediaRecorder || this.mediaRecorder.state === 'inactive') {
                    reject(new Error('No active recording to stop.'));
                    return;
                }
                
                const stopHandler = async () => {
                    try {
                        if (this.audioChunks.length === 0) {
                            reject(new Error('No audio data captured'));
                            return;
                        }
                        
                        // Get the MIME type from the recorder
                        const mimeType = this.mediaRecorder.mimeType || 'audio/mp3';
                        
                        // Create a blob from the chunks
                        const audioBlob = new Blob(this.audioChunks, { type: mimeType });
                        
                        // Log information about the audio for debugging
                        console.log(`Audio recording complete: Size=${audioBlob.size} bytes, Format=${mimeType}, Chunks=${this.audioChunks.length}`);
                        
                        if (audioBlob.size > 25 * 1024 * 1024) { // 25MB limit for Whisper
                            console.warn('Audio file exceeds Whisper size limit. Transcription may fail.');
                        }
                        
                        // Convert the blob to base64
                        const reader = new FileReader();
                        reader.onloadend = () => {
                            try {
                                const base64Audio = reader.result;
                                console.log(`Base64 audio length: ${base64Audio.length} chars`);
                                console.log(`Base64 prefix: ${base64Audio.substring(0, 50)}...`);
                                
                                resolve(base64Audio);
                            } catch (error) {
                                console.error('Error in reader.onloadend handler:', error);
                                reject(error);
                            }
                        };
                        reader.onerror = () => reject(new Error('Failed to read audio data'));
                        reader.readAsDataURL(audioBlob);
                    } catch (error) {
                        console.error('Error in mediaRecorder onstop handler:', error);
                        reject(error);
                    }
                };
                
                // Set one-time stop handler
                this.mediaRecorder.onstop = stopHandler;
                
                // Stop the recorder
                this.mediaRecorder.stop();
            });
            
            // Clean up recording resources
            this.releaseMediaResources();
            
            // Add user message with placeholder
            this.addUserMessage('...');
            
            // Process the audio with OpenAI Whisper
            console.log('Sending audio for transcription... Length: ' + audioBase64.length);
            console.log('Audio format prefix: ' + audioBase64.substring(0, 50) + '...');
            
            let transcriptionResult;
            try {
                console.log('Using client-side approach for audio processing');
                // Try client-side processing first
                transcriptionResult = await this.processAudioClientSide(audioBase64);
                console.log('Client-side transcription successful:', transcriptionResult);
            } catch (clientError) {
                console.warn('Client-side processing failed, falling back to server-side:', clientError);
                try {
                    // Fall back to server-side processing
                    transcriptionResult = await processAudio({ audioBase64 });
                    console.log('Server-side transcription received:', transcriptionResult);
                } catch (serverError) {
                    console.error('All transcription methods failed.');
                    console.error('Client-side error:', clientError);
                    console.error('Server-side error:', serverError);
                    
                    // Add a user-friendly message
                    this.updateLastUserMessage('Sorry, there was an error processing your audio. Please try again.');
                    this.updateStatus('Error', 'error');
                    
                    // Show toast with error details
                    this.showToast(
                        'Audio Processing Error', 
                        'There was an error processing your audio. Please try again with a shorter message or check your microphone setup.',
                        'error'
                    );
                    
                    // Provide blank response for graceful failure
                    transcriptionResult = { text: '' };
                }
            }
            
            const transcription = transcriptionResult?.text || '';
            if (!transcription) {
                this.updateLastUserMessage('(No speech detected)');
                this.updateStatus('Ready');
                return;
            }
            
            // Update the user message with the transcription
            this.updateLastUserMessage(transcription);

            // add loading bubble
            const typingMessageId = `typing-${Date.now()}`;
            this.messages.push({
                id: typingMessageId,
                sender: 'assistant',
                isTyping: true,
                cssClass: 'message assistant'
            });
            
            // Process with AgentForce
            console.log('Sending transcription to AgentForce...');
            const agentResult = await completeAgentForceConversation({
                userQuery: transcription,
                clientSessionId: this.sessionId,
                clientSequenceId: this.sequenceId
            });

            this.messages = this.messages.filter(msg => msg.id !== typingMessageId);

            if (agentResult && agentResult.success) {
                this.sessionId = agentResult.sessionId;
                this.sequenceId = agentResult.sequenceId;
            } else {
                this.sessionId = null;
                this.sequenceId = 1;
            }

            
            if (!agentResult || !agentResult.success) {
                const errorMsg = agentResult?.error || agentResult?.message || 'Unknown error';
                this.showToast('AgentForce Error', errorMsg, 'error');
                
                // Fall back to OpenAI
                console.log('Falling back to OpenAI...');
                const openAIResponse = await generateResponse({ userMessage: transcription });
                
                this.addAssistantMessage(openAIResponse);
                
                // Convert to speech
                try {
                    this.updateStatus('Converting to speech...', 'processing');
                    console.log('Sending text to TTS (fallback):', openAIResponse.substring(0, 100) + '...');
                    
                    const ttsAudio = await textToSpeech({ text: openAIResponse, voice: this.voice });
                    console.log('TTS response received (fallback), length:', ttsAudio ? ttsAudio.length : 'undefined');
                    
                    // Play the audio
                    this.updateStatus('Speaking', 'speaking');
                    await this.playAudio(ttsAudio);
                } catch (ttsError) {
                    console.error('Text-to-Speech error (fallback):', ttsError);
                    this.showToast('Text-to-Speech Error', 'Could not convert response to speech. Please check the console for details.', 'warning');
                }
            } else {
                // Show AgentForce response
                const assistantText = agentResult.agentResponse;
                console.log('assistantText:', assistantText, '| Type:', typeof assistantText);

                this.addAssistantMessage(assistantText);

                try {
                    this.updateStatus('Converting to speech...', 'processing');

                    let textToSpeak = assistantText;

                    // Summarize text
                    console.log('Requesting summary for voice...');
                    try {
                        const summarizationPrompt = 
                            'Please summarize the following message in one clear and natural response that would sound appropriate if spoken aloud by a voice assistant. ' +
                            'The summary should be conversational and helpful. Do not include URLs, IDs, or overly technical details unless absolutely necessary. ' +
                            'DO NOT ADD OR MODIFY ANY INFORMATION GIVEN!!' +
                            'Here is the message to summarize: ' + assistantText;
                        const openAIResponse = await generateResponse({ userMessage: summarizationPrompt });
                        if (openAIResponse) {
                            textToSpeak = openAIResponse;
                            console.log('Using summarized TTS:', textToSpeak);
                        } else {
                            console.warn('Summarization failed or returned no summary. Falling back to full response.');
                        }
                    } catch (summaryError) {
                        console.error('Error during summarization request:', summaryError);
                    }

                    // Convert text to speech (summary or fallback)
                    console.log('Sending text to TTS:', textToSpeak.substring(0, 100) + '...');
                    const ttsAudio = await textToSpeech({ text: textToSpeak, voice: this.voice });
                    console.log('TTS response received, length:', ttsAudio ? ttsAudio.length : 'undefined');

                    // Play the audio
                    this.updateStatus('Speaking', 'speaking');
                    await this.playAudio(ttsAudio);

                } catch (ttsError) {
                    console.error('Text-to-Speech error:', ttsError);
                    this.showToast('Text-to-Speech Error', 'Could not convert response to speech. Please check the console for details.', 'warning');
                }
            }
            
            this.updateStatus('Ready');
        } catch (error) {
            // Log the full error 
            console.error('Error in stopRecording:', error);
            
            // Derive a user-friendly message
            let errorMsg = 'Unknown error';
            if (error) {
                if (error.body && error.body.message) {
                    errorMsg = error.body.message;
                } else if (error.message) {
                    errorMsg = error.message;
                }
            }
            
            this.updateStatus('Error', 'error');
            this.showToast('Processing Error', `Failed to process recording: ${errorMsg}`, 'error');
            
            // Clean up
            this.releaseMediaResources();
        }
    }
    
    playAudio(base64Audio) {
        return new Promise((resolve, reject) => {
            try {
                console.log('Starting audio playback, data length:', base64Audio ? base64Audio.length : 'undefined');
                
                // Validate the audio data
                if (!base64Audio || typeof base64Audio !== 'string' || !base64Audio.startsWith('data:audio')) {
                    console.error('Invalid audio data format:', base64Audio ? base64Audio.substring(0, 50) + '...' : 'undefined');
                    throw new Error('Invalid audio data format');
                }
                
                // Extract the base64 data and MIME type
                const parts = base64Audio.split(',');
                const mime = parts[0].match(/:(.*?);/)[1];
                const base64Data = parts[1];
                
                // Convert base64 to Blob
                const byteCharacters = atob(base64Data);
                const byteArrays = [];
                
                for (let offset = 0; offset < byteCharacters.length; offset += 512) {
                    const slice = byteCharacters.slice(offset, offset + 512);
                    
                    const byteNumbers = new Array(slice.length);
                    for (let i = 0; i < slice.length; i++) {
                        byteNumbers[i] = slice.charCodeAt(i);
                    }
                    
                    const byteArray = new Uint8Array(byteNumbers);
                    byteArrays.push(byteArray);
                }
                
                const blob = new Blob(byteArrays, { type: mime });
                
                // Create a blob URL (which is allowed by CSP)
                const blobUrl = URL.createObjectURL(blob);
                console.log('Created blob URL for audio playback');
                
                // Create audio element
                const audio = new Audio();
                
                // Set up event listeners before setting src
                audio.onended = () => {
                    console.log('Audio playback completed');
                    // Revoke the blob URL to free memory
                    URL.revokeObjectURL(blobUrl);
                    resolve();
                };
                
                audio.onerror = (err) => {
                    console.error('Audio playback error:', err);
                    console.error('Audio error code:', audio.error ? audio.error.code : 'unknown');
                    // Revoke the blob URL even on error
                    URL.revokeObjectURL(blobUrl);
                    reject(new Error('Failed to play audio: ' + (audio.error ? audio.error.message : 'unknown error')));
                };
                
                audio.oncanplaythrough = () => {
                    console.log('Audio can play through, starting playback');
                    try {
                        // Use play() with catch for promise rejection
                        const playPromise = audio.play();
                        if (playPromise !== undefined) {
                            playPromise.catch(err => {
                                console.error('Play promise rejected:', err);
                                URL.revokeObjectURL(blobUrl);
                                reject(new Error('Playback failed: ' + err.message));
                            });
                        }
                    } catch (playError) {
                        console.error('Error in play():', playError);
                        URL.revokeObjectURL(blobUrl);
                        reject(playError);
                    }
                };
                
                // Set audio source to the blob URL (which is allowed by CSP)
                audio.src = blobUrl;
                audio.load();
            } catch (error) {
                console.error('Error setting up audio playback:', error);
                reject(error);
            }
        });
    }
    
    // MESSAGE HANDLING METHODS
    
    addUserMessage(text) {
        this.messages.push({
            id: Date.now().toString(),
            content: text,
            sender: 'user',
            timestamp: new Date().toISOString(),
            cssClass: 'message user'
        });
        this.scrollToBottom();
    }

    convertLinks(text) {
        // 1. Labeled link: "label" (url)
        const labeledLinkRegex = /"([^"]+)"\s*\(\s*(https?:\/\/[^\s)]+)\s*\)/g;
        let result = text.replace(labeledLinkRegex, (match, label, url) => {
            const safeUrl = url.replace(/"/g, '&quot;');
            const safeLabel = label.replace(/</g, '&lt;').replace(/>/g, '&gt;');
            return `<a href="${safeUrl}" target="_blank" rel="noopener noreferrer">${safeLabel}</a>`;
        });

        // 2. Markdown-style: [label](url)
        const markdownRegex = /\[([^\]]+)\]\(\s*(https?:\/\/[^\s)]+)\s*\)/g;
        result = result.replace(markdownRegex, (match, label, url) => {
            const safeUrl = url.replace(/"/g, '&quot;');
            const safeLabel = label.replace(/</g, '&lt;').replace(/>/g, '&gt;');
            return `<a href="${safeUrl}" target="_blank" rel="noopener noreferrer">${safeLabel}</a>`;
        });

        // 3. Bare URLs – wrap only those not already inside an anchor
        // Match URLs NOT preceded by a quote or equal sign (which often indicates an href="")
        const bareUrlRegex = /(?<!["'=])\b(https?:\/\/[^\s<>"')]+)/g;
        result = result.replace(bareUrlRegex, (url) => {
            const safeUrl = url.replace(/"/g, '&quot;');
            return `<a href="${safeUrl}" target="_blank" rel="noopener noreferrer">${safeUrl}</a>`;
        });

        return result;
    }
    
    addAssistantMessage(text) {
        const formattedText = this.convertLinks(text);
        const id = Date.now().toString();

        this.messages.push({
            id,
            content: text,
            html: formattedText,
            sender: 'assistant',
            timestamp: new Date().toISOString(),
            cssClass: 'message assistant'
        });

        this.lastHtmlMessageId = id;
        this.scrollToBottom();
    }

    renderedCallback() {
        if (this.lastHtmlMessageId) {
            const selector = `[data-id="${this.lastHtmlMessageId}"] .rendered-html`;
            const container = this.template.querySelector(selector);
            const message = this.messages.find(m => m.id === this.lastHtmlMessageId);
            
            if (container && message?.html) {
                container.innerHTML = message.html;
                this.lastHtmlMessageId = null; // reset after rendering
            }
        }
    }
    
    updateLastUserMessage(text) {
        // Update the last user message content
        
        // Find the last user message
        const lastUserMessageIndex = [...this.messages].reverse().findIndex(msg => msg.sender === 'user');
        
        if (lastUserMessageIndex !== -1) {
            // Update the last user message
            const actualIndex = this.messages.length - 1 - lastUserMessageIndex;
            this.messages[actualIndex].content = text;
            
            // Force refresh
            this.messages = [...this.messages];
        } else {
            // If there's no existing user message, create one
            this.addUserMessage(text);
        }
    }
    
    getLastUserMessage() {
        return [...this.messages].reverse().find(msg => msg.sender === 'user');
    }
    
    // UI HELPER METHODS
    
    updateStatus(text, lightClass = '') {
        this.status = text;
        this.statusClass = lightClass;
    }
    
    scrollToBottom() {
        window.setTimeout(() => {
            const container = this.template.querySelector('.conversation');
            if (container) {
                container.scrollTop = container.scrollHeight;
            }
        }, 100);
    }
    
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }
    
    // EVENT HANDLERS
    
    handleVoiceChange(event) {
        this.voice = event.target.value;
    }
    
    handleOpenSettings() {
        // Navigate to Visualforce settings page
        window.open('/apex/VoiceAssistantSettings', '_blank');
    }

    // MANUAL CHAT METHODS

    handleChatInputChange(event) {
        this.chatInput = event.target.value;
    }

    handleChatKeyPress(event) {
        if (event.key === 'Enter' && !event.shiftKey) {
            event.preventDefault();
            this.sendChatMessage();
        }
    }

    handleSendChatMessage() {
        this.sendChatMessage();
    }

    async sendChatMessage() {
        const message = this.chatInput.trim();
        console.log('Chat message:', message);
        if (!message) {
            return;
        }

        // Clear input
        this.chatInput = '';

        // Add user message
        this.addUserMessage(message);

        try {
            // Add loading bubble
            const typingMessageId = `typing-${Date.now()}`;
            this.messages.push({
                id: typingMessageId,
                sender: 'assistant',
                isTyping: true,
                cssClass: 'message assistant'
            });

            // Process with AgentForce (same as voice)
            console.log('Sending text message to AgentForce...');
            const agentResult = await completeAgentForceConversation({
                userQuery: message,
                clientSessionId: this.sessionId,
                clientSequenceId: this.sequenceId
            });

            this.messages = this.messages.filter(msg => msg.id !== typingMessageId);

            if (agentResult && agentResult.success) {
                this.sessionId = agentResult.sessionId;
                this.sequenceId = agentResult.sequenceId;
            } else {
                this.sessionId = null;
                this.sequenceId = 1;
            }

            if (!agentResult || !agentResult.success) {
                const errorMsg = agentResult?.error || agentResult?.message || 'Unknown error';
                this.showToast('AgentForce Error', errorMsg, 'error');

                // Fall back to OpenAI
                console.log('Falling back to OpenAI...');
                const openAIResponse = await generateResponse({ userMessage: message });
                this.addAssistantMessage(openAIResponse);

            } else {
                // Show AgentForce response
                const assistantText = agentResult.agentResponse;
                this.addAssistantMessage(assistantText);
            }

        } catch (error) {
            console.error('Error processing chat message:', error);

            let errorMsg = 'Unknown error';
            if (error) {
                if (error.body && error.body.message) {
                    errorMsg = error.body.message;
                } else if (error.message) {
                    errorMsg = error.message;
                }
            }

            this.showToast('Processing Error', `Failed to process message: ${errorMsg}`, 'error');
        }
    }
}