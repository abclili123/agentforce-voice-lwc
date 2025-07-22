// messagingService.js (LWC client-side wrapper)

import startConversationApex from '@salesforce/apex/MessagingServiceController.startConversation';
import sendMessageApex from '@salesforce/apex/MessagingServiceController.sendMessageToAgent';
import getMessagesApex from '@salesforce/apex/MessagingServiceController.getMessages';

let conversationId = null;

export async function initMessagingSession() {
    try {
        const result = await startConversationApex();
        const parsed = JSON.parse(result);
        conversationId = parsed.conversationId;
        console.log('Started conversation:', conversationId);
    } catch (error) {
        console.error('Failed to initialize messaging session:', error);
        throw error;
    }
}

export async function sendMessageToAgentForce(text) {
    if (!conversationId) {
        throw new Error('Conversation not initialized. Call initMessagingSession first.');
    }
    try {
        await sendMessageApex({
            conversationId,
            text
        });
    } catch (error) {
        console.error('Failed to send message:', error);
        throw error;
    }
}

export async function getMessages() {
    if (!conversationId) {
        throw new Error('Conversation not initialized.');
    }
    try {
        const result = await getMessagesApex({ conversationId });
        return JSON.parse(result).messages || [];
    } catch (error) {
        console.error('Failed to get messages:', error);
        throw error;
    }
}

export function getLastAgentMessage(messages) {
    const reversed = [...messages].reverse();
    return reversed.find(m => m.sender === 'agent' || m.sender === 'bot')?.message || null;
}