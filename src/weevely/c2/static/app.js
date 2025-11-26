const API_BASE = '/';

// State
let agents = [];
let activeAgentId = null;
let commandHistory = [];
let historyIndex = -1;
let currentInput = '';

// DOM Elements
const agentList = document.getElementById('agent-list');
const emptyState = document.getElementById('empty-state');
const terminalContainer = document.getElementById('terminal-container');
const activeAgentAlias = document.getElementById('active-agent-alias');
const activeAgentUrl = document.getElementById('active-agent-url');
const terminalOutput = document.getElementById('terminal-output');
const terminalInput = document.getElementById('terminal-input');
const addAgentModal = document.getElementById('add-agent-modal');
const addAgentForm = document.getElementById('add-agent-form');
const toastContainer = document.getElementById('toast-container');
const sysTime = document.getElementById('sys-time');

// Init
async function init() {
    startClock();
    await fetchAgents();
    setupEventListeners();

    // Poll for status updates every 5 seconds
    setInterval(fetchAgents, 5000);
}

function startClock() {
    setInterval(() => {
        const now = new Date();
        sysTime.textContent = now.toLocaleTimeString('en-US', { hour12: false });
    }, 1000);
}

async function fetchAgents() {
    try {
        const res = await fetch(`${API_BASE}/agents/`);
        const newAgents = await res.json();
        agents = newAgents;
        renderAgents();
    } catch (e) {
        console.error('Failed to fetch agents', e);
    }
}

function renderAgents() {
    agentList.innerHTML = '';
    agents.forEach(agent => {
        const li = document.createElement('li');
        li.className = `agent-item ${activeAgentId === agent.id ? 'active' : ''}`;

        const statusClass = agent.status ? agent.status.toLowerCase() : 'unknown';

        li.innerHTML = `
            <div class="agent-info">
                <span class="agent-alias">${agent.alias || 'UNNAMED_UNIT'}</span>
                <span class="agent-url">${agent.url}</span>
            </div>
            <div class="agent-status ${statusClass}" title="${agent.status}"></div>
        `;
        li.onclick = () => selectAgent(agent);
        agentList.appendChild(li);
    });
}

async function selectAgent(agent) {
    if (activeAgentId === agent.id) return;

    activeAgentId = agent.id;
    renderAgents();

    emptyState.style.display = 'none';
    terminalContainer.classList.remove('hidden');

    activeAgentAlias.textContent = (agent.alias || 'UNNAMED').toUpperCase();
    activeAgentUrl.textContent = agent.url;

    terminalOutput.innerHTML = '';
    appendOutput(`[SYSTEM] ESTABLISHING UPLINK TO ${agent.url}...`, 'system');
    appendOutput(`[SYSTEM] ENCRYPTION: AES-128-CBC // COMPRESSION: GZIP`, 'system');
    appendOutput(`[SYSTEM] CONNECTION ESTABLISHED.`, 'success');

    // Reset history state
    commandHistory = [];
    historyIndex = -1;
    currentInput = '';

    // Fetch history
    await fetchHistory(agent.id);

    terminalInput.focus();
}

async function fetchHistory(agentId) {
    try {
        const res = await fetch(`${API_BASE}/agents/${agentId}/history`);
        const history = await res.json();

        history.forEach(log => {
            appendOutput(`root@weevely:~# ${log.command}`, 'command');
            appendOutput(log.output);
            commandHistory.push(log.command);
        });

        scrollToBottom();
        historyIndex = commandHistory.length;
    } catch (e) {
        console.error('Failed to fetch history', e);
        showToast('DATA RETRIEVAL FAILED', 'error');
    }
}

async function handleCommand(cmd) {
    if (!activeAgentId || !cmd.trim()) return;

    commandHistory.push(cmd);
    historyIndex = commandHistory.length;

    appendOutput(`root@weevely:~# ${cmd}`, 'command');
    terminalInput.value = '';

    try {
        const res = await fetch(`${API_BASE}/agents/${activeAgentId}/exec?cmd=${encodeURIComponent(cmd)}`, {
            method: 'POST'
        });
        const data = await res.json();

        if (data.result) {
            appendOutput(data.result);
        } else {
            appendOutput('[NO OUTPUT RETURNED]');
        }
    } catch (e) {
        appendOutput(`[ERROR] ${e.message}`, 'error');
        showToast('EXECUTION FAILED', 'error');
    }

    scrollToBottom();
}

function appendOutput(text, type = 'normal') {
    const div = document.createElement('div');
    div.textContent = text;
    if (type === 'command') div.style.color = '#fff';
    if (type === 'error') div.style.color = '#ff0055';
    if (type === 'system') div.style.color = '#00f3ff';
    if (type === 'success') div.style.color = '#00ff9d';
    terminalOutput.appendChild(div);
}

function scrollToBottom() {
    terminalOutput.scrollTop = terminalOutput.scrollHeight;
}

function setupEventListeners() {
    // Terminal Input
    terminalInput.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') {
            handleCommand(terminalInput.value);
        } else if (e.key === 'ArrowUp') {
            e.preventDefault();
            if (historyIndex > 0) {
                if (historyIndex === commandHistory.length) {
                    currentInput = terminalInput.value;
                }
                historyIndex--;
                terminalInput.value = commandHistory[historyIndex];
            }
        } else if (e.key === 'ArrowDown') {
            e.preventDefault();
            if (historyIndex < commandHistory.length) {
                historyIndex++;
                if (historyIndex === commandHistory.length) {
                    terminalInput.value = currentInput;
                } else {
                    terminalInput.value = commandHistory[historyIndex];
                }
            }
        }
    });

    // Add Agent Modal
    const addBtn = document.getElementById('add-agent-btn');
    const cancelBtn = document.getElementById('cancel-add-agent');

    addBtn.onclick = () => addAgentModal.classList.add('show');
    cancelBtn.onclick = () => addAgentModal.classList.remove('show');

    addAgentForm.onsubmit = async (e) => {
        e.preventDefault();
        const formData = new FormData(addAgentForm);
        const agentData = Object.fromEntries(formData.entries());

        try {
            const res = await fetch(`${API_BASE}/agents/`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(agentData)
            });

            if (res.ok) {
                const newAgent = await res.json();
                addAgentModal.classList.remove('show');
                addAgentForm.reset();
                await fetchAgents();
                selectAgent(newAgent);
                showToast('AGENT DEPLOYED SUCCESSFULLY', 'success');
            } else {
                showToast('DEPLOYMENT FAILED', 'error');
            }
        } catch (e) {
            console.error(e);
            showToast('SYSTEM ERROR', 'error');
        }
    };
}

function showToast(message, type = 'info') {
    const toast = document.createElement('div');
    toast.className = `toast ${type}`;
    toast.textContent = `>> ${message}`;

    toastContainer.appendChild(toast);

    setTimeout(() => {
        toast.style.opacity = '0';
        toast.style.transform = 'translateX(100%)';
        setTimeout(() => toast.remove(), 300);
    }, 3000);
}

init();
