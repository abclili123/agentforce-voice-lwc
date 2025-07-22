// messagingService.js (LWC client-side wrapper)

import startConversation from '@salesforce/apex/MessagingServiceController.startConversation';
import sendMessageToAgent from '@salesforce/apex/MessagingServiceController.sendMessageToAgent';
import getMessages from '@salesforce/apex/MessagingServiceController.getMessages';

let conversationId = null;

export async function initMessagingSession() {
    try {
        const result = await startConversation();
        console.log('Start conversation result: ', result);
        conversationId = result?.conversation?.conversationId;
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
        await sendMessageToAgent({
            conversationId,
            text
        });
    } catch (error) {
        console.error('Failed to send message:', error);
        throw error;
    }
}

export async function getMessagesFromServer() {
    if (!conversationId) {
        throw new Error('Conversation not initialized.');
    }
    try {
        const result = await getMessages({ conversationId });
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