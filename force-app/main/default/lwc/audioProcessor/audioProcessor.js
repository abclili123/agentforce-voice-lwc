/**
 * Audio Processor Utility for Voice Assistant
 * This module handles browser audio recording functionality
 */
export class AudioProcessor {
    constructor() {
        this.mediaRecorder = null;
        this.audioChunks = [];
        this.audioContext = null;
        this.stream = null;
        this.vadProcessorInterval = null;
    }
    
    async initAudioContext() {
        if (!this.audioContext) {
            try {
                this.audioContext = new (window.AudioContext || window.webkitAudioContext)();
                console.log("AudioContext initialized successfully:", this.audioContext);
                return this.audioContext;
            } catch (error) {
                console.error('Failed to create AudioContext:', error);
                throw new Error('Failed to initialize audio context. Your browser might not support the Web Audio API.');
            }
        }
        return this.audioContext;
    }
    
    async requestMicrophoneAccess() {
        try {
            console.log("Requesting microphone access...");
            
            // Check if the browser supports getUserMedia
            if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
                throw new Error("Your browser doesn't support the required microphone access APIs");
            }
            
            const audioConstraints = {
                audio: {
                    echoCancellation: true,
                    noiseSuppression: true,
                    sampleRate: 44100
                }
            };
            // Try with more permissive constraints first
            this.stream = await navigator.mediaDevices.getUserMedia(audioConstraints);
            
            console.log("Microphone access granted successfully", this.stream);
            return this.stream;
        } catch (error) {
            console.error('Error accessing microphone:', error);
            
            // Provide more detailed error message based on the error name
            if (error.name === 'NotAllowedError' || error.name === 'PermissionDeniedError') {
                throw new Error('Microphone access was denied. Please allow microphone access in your browser settings and refresh the page.');
            } else if (error.name === 'NotFoundError' || error.name === 'DevicesNotFoundError') {
                throw new Error('No microphone was found on your device. Please connect a microphone and try again.');
            } else if (error.name === 'NotReadableError' || error.name === 'TrackStartError') {
                throw new Error('Your microphone is busy or unavailable. Please close other applications that might be using it.');
            } else if (error.name === 'OverconstrainedError' || error.name === 'ConstraintNotSatisfiedError') {
                throw new Error('Could not apply audio constraints. Your microphone might not support the requested settings.');
            } else {
                throw new Error(`Failed to access microphone: ${error.message}`);
            }
                const micErrorEvent = new CustomEvent('microphoneerror', { detail: error });
                window.dispatchEvent(micErrorEvent);
        }
    }
    
    async startRecording() {
        try {
            console.log("Starting recording...");
            
            // Initialize the audio context first
            await this.initAudioContext();
            
            // Get microphone access
            const stream = await this.requestMicrophoneAccess();
            
            // Debug: Log the tracks from the stream
            const audioTracks = stream.getAudioTracks();
            console.log("Audio tracks:", audioTracks);
            console.log("Audio track settings:", audioTracks[0].getSettings());
            
            // Clear any previous recording
            this.audioChunks = [];
            
            // Try to create MediaRecorder with options, fall back to defaults if needed
            try {
                this.mediaRecorder = new MediaRecorder(stream, {
                    mimeType: 'audio/webm'
                });
                console.log("MediaRecorder created with audio/webm", this.mediaRecorder);
            } catch (e) {
                console.warn("audio/webm not supported, trying with default MIME type", e);
                this.mediaRecorder = new MediaRecorder(stream);
                console.log("MediaRecorder created with default MIME type", this.mediaRecorder);
            }
            
            // Set up event handlers
            this.mediaRecorder.ondataavailable = (event) => {
                console.log("Data available from MediaRecorder:", event.data.size);
                if (event.data.size > 0) {
                    this.audioChunks.push(event.data);
                }
            };
            
            this.mediaRecorder.onerror = (event) => {
                console.error("MediaRecorder error:", event);
            };
            
            this.mediaRecorder.onstart = () => {
                console.log("MediaRecorder started successfully");
            };
            
            // Start recording
            this.mediaRecorder.start(100); // Collect data in 100ms chunks
            
            return true;
        } catch (error) {
            console.error('Error starting recording:', error);
            throw error;
        }
    }
    
    async stopRecording() {
        return new Promise((resolve, reject) => {
            if (!this.mediaRecorder || this.mediaRecorder.state === 'inactive') {
                reject(new Error('No active recording to stop.'));
                return;
            }
            
            console.log("Stopping recording...");
            
            this.mediaRecorder.onstop = async () => {
                try {
                    console.log("MediaRecorder stopped, processing chunks...");
                    console.log("Number of audio chunks:", this.audioChunks.length);
                    
                    if (this.audioChunks.length === 0) {
                        reject(new Error('No audio data was captured.'));
                        return;
                    }
                    
                    // Convert audio chunks to a single Blob
                    let mimeType = 'audio/webm';
                    if (this.mediaRecorder.mimeType) {
                        mimeType = this.mediaRecorder.mimeType;
                    }
                    
                    const audioBlob = new Blob(this.audioChunks, { type: mimeType });
                    console.log("Created audio blob:", audioBlob.size, "bytes,", "type:", mimeType);
                    
                    // Convert to base64
                    const base64Audio = await this.blobToBase64(audioBlob);
                    console.log("Converted to base64, length:", base64Audio.length);
                    
                    resolve(base64Audio);
                } catch (error) {
                    console.error("Error processing recorded audio:", error);
                    reject(error);
                }
            };
            
            try {
                this.mediaRecorder.stop();
            } catch (error) {
                console.error("Error stopping MediaRecorder:", error);
                reject(error);
            }
        });
    }
    
    async blobToBase64(blob) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onloadend = () => {
                console.log("FileReader loaded successfully");
                resolve(reader.result);
            };
            reader.onerror = (error) => {
                console.error("FileReader error:", error);
                reject(error);
            };
            reader.readAsDataURL(blob);
        });
    }
    
    startVADProcessing(callback) {
        // Clear any existing interval
        if (this.vadProcessorInterval) {
            clearInterval(this.vadProcessorInterval);
        }
        
        // Initialize recording if not already started
        this.startRecording()
            .then(() => {
                console.log("VAD processing started");
                // Set up an interval to collect and process audio chunks regularly
                this.vadProcessorInterval = setInterval(async () => {
                    if (this.mediaRecorder && this.mediaRecorder.state === 'recording' && this.audioChunks.length > 0) {
                        // Create a copy of the current chunks
                        const currentChunks = [...this.audioChunks];
                        
                        // Clear the chunks for the next interval
                        this.audioChunks = [];
                        
                        // Create a blob from the current chunks
                        let mimeType = 'audio/webm';
                        if (this.mediaRecorder.mimeType) {
                            mimeType = this.mediaRecorder.mimeType;
                        }
                        
                        const audioBlob = new Blob(currentChunks, { type: mimeType });
                        
                        // Convert to base64
                        const base64Audio = await this.blobToBase64(audioBlob);
                        
                        // Send to the callback
                        callback(base64Audio);
                    }
                }, 1000); // Process every 1 second
            })
            .catch(error => {
                console.error('Error starting VAD processing:', error);
                throw error;
            });
    }
    
    stopVADProcessing() {
        if (this.vadProcessorInterval) {
            clearInterval(this.vadProcessorInterval);
            this.vadProcessorInterval = null;
        }
        
        if (this.mediaRecorder && this.mediaRecorder.state === 'recording') {
            this.mediaRecorder.stop();
        }
    }
    
    // Helper methods for audio processing
    base64ToAudio(base64Data) {
        // Remove the data URL prefix if present
        const base64String = base64Data.split(',')[1] || base64Data;
        
        // Convert base64 to binary
        const binaryString = atob(base64String);
        
        // Create an array buffer
        const bytes = new Uint8Array(binaryString.length);
        for (let i = 0; i < binaryString.length; i++) {
            bytes[i] = binaryString.charCodeAt(i);
        }
        
        // Create a blob
        return new Blob([bytes], { type: 'audio/mp3' });
    }
    
    playAudio(base64Audio) {
        const audioBlob = this.base64ToAudio(base64Audio);
        const audioUrl = URL.createObjectURL(audioBlob);
        const audio = new Audio(audioUrl);
        
        audio.onended = () => {
            URL.revokeObjectURL(audioUrl);
        };
        
        return audio.play();
    }
}