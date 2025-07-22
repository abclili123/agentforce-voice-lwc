// messagingService.js

let SCRT_URL = 'https://orgfarm-7428735f60-dev-ed.develop.my.salesforce-scrt.com';
let ORG_ID = '00DgL000006ain3';
let ES_DEPLOYMENT_NAME = 'Chatterbox_Custom_Front_End';

let accessToken = null;
let conversationId = null;

export async function initMessagingSession() {
    if (!accessToken) {
        await fetchAccessToken();
    }
    if (!conversationId) {
        await startConversation();
    }
}

async function fetchAccessToken() {
    const res = await fetch(`${SCRT_URL}/iamessage/api/v2/authorization/unauthenticated/access-token`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            orgId: ORG_ID,
            esDeveloperName: ES_DEPLOYMENT_NAME,
            capabilitiesVersion: '1',
            platform: 'Web'
        })
    });
    const json = await res.json();
    accessToken = json.token;
}

async function startConversation() {
    const res = await fetch(`${SCRT_URL}/iamessage/api/v2/conversations`, {
        method: 'POST',
        headers: {
            'Authorization': `Bearer ${accessToken}`,
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            conversationId: generateUUID(),
            esDeveloperName: ES_DEPLOYMENT_NAME
        })
    });
    const json = await res.json();
    conversationId = json.conversationId;
    console.log('Started conversation:', conversationId);
}

export async function routeToAgentForce(flowId = null, type = 'initial') {
    const payload = { routingType: type };
    if (flowId) payload.flowId = flowId;

    await fetch(`${SCRT_URL}/iamessage/api/v2/conversations/${conversationId}/route`, {
        method: 'POST',
        headers: {
            'Authorization': `Bearer ${accessToken}`,
            'Content-Type': 'application/json'
        },
        body: JSON.stringify(payload)
    });
}

export async function sendMessageToAgentForce(text) {
    await fetch(`${SCRT_URL}/iamessage/api/v2/conversations/${conversationId}/messages`, {
        method: 'POST',
        headers: {
            'Authorization': `Bearer ${accessToken}`,
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            message: {
                type: 'Text',
                text
            }
        })
    });
}

export async function getMessages() {
    const res = await fetch(`${SCRT_URL}/iamessage/api/v2/conversations/${conversationId}/messages`, {
        method: 'GET',
        headers: {
            'Authorization': `Bearer ${accessToken}`
        }
    });
    const json = await res.json();
    return json.messages || [];
}

export function getLastAgentMessage(messages) {
    const reversed = [...messages].reverse();
    return reversed.find(m => m.sender === 'agent' || m.sender === 'bot')?.message || null;
}

function generateUUID() {
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, c => {
        const r = Math.random() * 16 | 0, v = c === 'x' ? r : (r & 0x3 | 0x8);
        return v.toString(16);
    });
}
