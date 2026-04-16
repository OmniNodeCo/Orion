let messages = [];
let isGenerating = false;
let chatCount = 0;
let modelData = [];
let updatePolling = null;

// Initialize
document.addEventListener("DOMContentLoaded", () => {
    loadModels();
    checkStatus();
    setInterval(checkStatus, 10000);
});

// Load models from Ollama
async function loadModels() {
    try {
        const response = await fetch("/api/models");
        const data = await response.json();
        const select = document.getElementById("modelSelect");
        select.innerHTML = "";

        if (data.models && data.models.length > 0) {
            modelData = data.models;
            data.models.forEach(model => {
                const option = document.createElement("option");
                option.value = model.name;
                option.textContent = model.name;
                if (model.name.includes("Orion") || model.name.includes("orion")) {
                    option.selected = true;
                }
                select.appendChild(option);
            });
            updateHeaderModel();
        }
    } catch (error) {
        console.error("Failed to load models:", error);
    }
}

// Check Ollama status
async function checkStatus() {
    const dot = document.getElementById("statusDot");
    const text = document.getElementById("statusText");
    try {
        const response = await fetch("/api/models");
        if (response.ok) {
            dot.className = "status-dot online";
            text.textContent = "Ollama Online";
        }
    } catch {
        dot.className = "status-dot";
        text.textContent = "Ollama Offline";
    }
}

// Update header model name
function updateHeaderModel() {
    const select = document.getElementById("modelSelect");
    document.getElementById("headerModel").textContent = select.value;
}

document.getElementById("modelSelect")?.addEventListener("change", updateHeaderModel);

// Toggle sidebar (mobile)
function toggleSidebar() {
    document.getElementById("sidebar").classList.toggle("open");
}

// Handle Enter key
function handleKey(event) {
    if (event.key === "Enter" && !event.shiftKey) {
        event.preventDefault();
        sendMessage();
    }
}

// Auto resize textarea
function autoResize(el) {
    el.style.height = "auto";
    el.style.height = Math.min(el.scrollHeight, 120) + "px";
}

// Send hint
function sendHint(text) {
    document.getElementById("chatInput").value = text;
    sendMessage();
}

// Send message
async function sendMessage() {
    const input = document.getElementById("chatInput");
    const text = input.value.trim();
    if (!text || isGenerating) return;

    const welcome = document.getElementById("welcomeScreen");
    if (welcome) welcome.style.display = "none";

    messages.push({ role: "user", content: text });
    appendMessage("user", text);

    input.value = "";
    input.style.height = "auto";

    const typingId = showTyping();
    isGenerating = true;
    document.getElementById("sendBtn").disabled = true;

    try {
        const model = document.getElementById("modelSelect").value;
        const response = await fetch("/api/chat", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ model, messages })
        });

        const reader = response.body.getReader();
        const decoder = new TextDecoder();
        let aiContent = "";

        removeTyping(typingId);
        const aiMessageId = appendMessage("ai", "");

        while (true) {
            const { done, value } = await reader.read();
            if (done) break;

            const chunk = decoder.decode(value);
            const lines = chunk.split("\n");

            for (const line of lines) {
                if (line.startsWith("data: ")) {
                    try {
                        const data = JSON.parse(line.slice(6));
                        if (data.content) {
                            aiContent += data.content;
                            updateMessage(aiMessageId, aiContent);
                        }
                        if (data.done) break;
                        if (data.error) {
                            updateMessage(aiMessageId, "⚠️ Error: " + data.error);
                            break;
                        }
                    } catch (e) {}
                }
            }
        }

        messages.push({ role: "assistant", content: aiContent });
        addToHistory(text);

    } catch (error) {
        removeTyping(typingId);
        appendMessage("ai", "⚠️ Connection error. Is Ollama running?");
    }

    isGenerating = false;
    document.getElementById("sendBtn").disabled = false;
}

// Append message
function appendMessage(role, content) {
    const container = document.getElementById("chatMessages");
    const id = "msg-" + Date.now();

    const avatar = role === "user" ? "👤" : "◉";
    const avatarClass = role === "user" ? "user" : "ai";

    const div = document.createElement("div");
    div.className = "message";
    div.id = id;
    div.innerHTML = `
        <div class="message-avatar ${avatarClass}">${avatar}</div>
        <div class="message-content ${avatarClass}">${formatContent(content)}</div>
    `;

    container.appendChild(div);
    container.scrollTop = container.scrollHeight;
    return id;
}

// Update message
function updateMessage(id, content) {
    const msg = document.getElementById(id);
    if (msg) {
        const contentDiv = msg.querySelector(".message-content");
        contentDiv.innerHTML = formatContent(content);
        const container = document.getElementById("chatMessages");
        container.scrollTop = container.scrollHeight;
    }
}

// Format content
function formatContent(text) {
    if (!text) return "";
    text = text.replace(/```(\w*)\n([\s\S]*?)```/g, '<pre><code>$2</code></pre>');
    text = text.replace(/`([^`]+)`/g, '<code>$1</code>');
    text = text.replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>');
    text = text.replace(/\*(.*?)\*/g, '<em>$1</em>');
    text = text.replace(/\n/g, '<br>');
    return text;
}

// Show typing
function showTyping() {
    const container = document.getElementById("chatMessages");
    const id = "typing-" + Date.now();

    const div = document.createElement("div");
    div.className = "message";
    div.id = id;
    div.innerHTML = `
        <div class="message-avatar ai">◉</div>
        <div class="message-content ai">
            <div class="typing-indicator">
                <div class="typing-dot"></div>
                <div class="typing-dot"></div>
                <div class="typing-dot"></div>
            </div>
        </div>
    `;

    container.appendChild(div);
    container.scrollTop = container.scrollHeight;
    return id;
}

// Remove typing
function removeTyping(id) {
    const el = document.getElementById(id);
    if (el) el.remove();
}

// Add to history
function addToHistory(text) {
    chatCount++;
    const history = document.getElementById("chatHistory");
    const item = document.createElement("div");
    item.className = "history-item";
    item.textContent = text.substring(0, 30) + (text.length > 30 ? "..." : "");
    history.appendChild(item);
}

// New chat
function newChat() {
    messages = [];
    document.getElementById("chatMessages").innerHTML = `
        <div class="welcome-screen" id="welcomeScreen">
            <div class="welcome-icon">◉</div>
            <h2>Welcome to Orion</h2>
            <p>Shy, calm, and concise AI assistant by OmniNode</p>
            <div class="welcome-hints">
                <div class="hint" onclick="sendHint('Hello Orion')">👋 Say Hello</div>
                <div class="hint" onclick="sendHint('What can you do?')">🧠 Capabilities</div>
                <div class="hint" onclick="sendHint('Write me a Python script')">💻 Code Help</div>
                <div class="hint" onclick="sendHint('Tell me a fun fact')">🎯 Fun Fact</div>
            </div>
        </div>
    `;
    document.getElementById("sidebar").classList.remove("open");
}

// Clear chat
function clearChat() {
    newChat();
    document.getElementById("chatHistory").innerHTML = "<label>HISTORY</label>";
}

// ==========================================
// MODEL MANAGER
// ==========================================

// Open Model Manager
async function openModelManager() {
    document.getElementById("modelManagerModal").classList.add("active");
    await loadModelList();
}

// Close Model Manager
function closeModelManager() {
    document.getElementById("modelManagerModal").classList.remove("active");
    if (updatePolling) {
        clearInterval(updatePolling);
        updatePolling = null;
    }
}

// Format file size
function formatSize(bytes) {
    if (!bytes) return "Unknown";
    const gb = bytes / (1024 * 1024 * 1024);
    if (gb >= 1) return gb.toFixed(1) + " GB";
    const mb = bytes / (1024 * 1024);
    return mb.toFixed(0) + " MB";
}

// Load model list into modal
async function loadModelList() {
    const container = document.getElementById("modelList");
    container.innerHTML = '<div class="loading-models"><span class="spinner">🔄</span> Loading models...</div>';

    try {
        const response = await fetch("/api/models");
        const data = await response.json();

        if (!data.models || data.models.length === 0) {
            container.innerHTML = '<div class="loading-models">No models found</div>';
            return;
        }

        modelData = data.models;
        renderModelCards();

    } catch (error) {
        container.innerHTML = `<div class="loading-models">⚠️ Error: ${error.message}</div>`;
    }
}

// Render model cards
function renderModelCards() {
    const container = document.getElementById("modelList");
    container.innerHTML = "";

    modelData.forEach(model => {
        const card = document.createElement("div");
        card.className = "model-card";
        card.id = `model-card-${model.name.replace(/[^a-zA-Z0-9]/g, "-")}`;

        let statusBadge = '<span class="status-badge unknown">⏳ Not Checked</span>';
        let progressBar = '';
        let actionButtons = '';

        if (model.update_checking) {
            statusBadge = '<span class="status-badge checking"><span class="spinner">🔄</span> Checking...</span>';
        } else if (model.update_downloading) {
            statusBadge = `<span class="status-badge downloading"><span class="spinner">⬇️</span> Downloading ${model.update_progress}%</span>`;
            progressBar = `
                <div class="progress-container active">
                    <div class="progress-bar" style="width: ${model.update_progress}%"></div>
                </div>
            `;
        } else if (model.update_error) {
            statusBadge = `<span class="status-badge error">❌ Error</span>`;
        } else if (model.up_to_date) {
            statusBadge = '<span class="status-badge up-to-date">✅ Up to Date</span>';
        } else if (model.updated) {
            statusBadge = '<span class="status-badge updated">🎉 Updated!</span>';
        }

        const isProcessing = model.update_checking || model.update_downloading;

        card.innerHTML = `
            <div class="model-card-header">
                <span class="model-card-name">${model.name}</span>
                <span class="model-card-size">${formatSize(model.size)}</span>
            </div>
            <div class="model-card-status">
                ${statusBadge}
            </div>
            ${progressBar}
            <div class="model-card-actions">
                <button class="model-action-btn check" 
                    onclick="checkSingleUpdate('${model.name}')"
                    ${isProcessing ? 'disabled' : ''}>
                    🔍 Check
                </button>
                <button class="model-action-btn update" 
                    onclick="updateSingleModel('${model.name}')"
                    ${isProcessing ? 'disabled' : ''}>
                    ⬇️ Update
                </button>
                <button class="model-action-btn delete" 
                    onclick="deleteModel('${model.name}')"
                    ${isProcessing ? 'disabled' : ''}>
                    🗑 Delete
                </button>
            </div>
        `;

        container.appendChild(card);
    });
}

// Check single model update
async function checkSingleUpdate(modelName) {
    try {
        // Update local state
        const model = modelData.find(m => m.name === modelName);
        if (model) {
            model.update_checking = true;
            model.up_to_date = false;
            model.updated = false;
            model.update_error = null;
        }
        renderModelCards();

        await fetch("/api/models/check-update", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ model: modelName })
        });

        // Start polling for status
        startUpdatePolling();

    } catch (error) {
        console.error("Check update error:", error);
    }
}

// Check all models for updates
async function checkAllUpdates() {
    const btn = document.getElementById("checkAllBtn");
    btn.disabled = true;
    btn.innerHTML = '<span class="spinner">🔄</span> Checking...';

    document.getElementById("modalFooterText").textContent = "Checking all models for updates...";

    // Mark all as checking
    modelData.forEach(model => {
        model.update_checking = true;
        model.up_to_date = false;
        model.updated = false;
        model.update_error = null;
    });
    renderModelCards();

    try {
        await fetch("/api/models/check-all", {
            method: "POST",
            headers: { "Content-Type": "application/json" }
        });

        startUpdatePolling();

    } catch (error) {
        console.error("Check all error:", error);
        btn.disabled = false;
        btn.innerHTML = "🔄 Check All Updates";
    }
}

// Update single model
async function updateSingleModel(modelName) {
    try {
        const model = modelData.find(m => m.name === modelName);
        if (model) {
            model.update_downloading = true;
            model.update_checking = false;
            model.update_progress = 0;
        }
        renderModelCards();

        await fetch("/api/models/update", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ model: modelName })
        });

        startUpdatePolling();

    } catch (error) {
        console.error("Update error:", error);
    }
}

// Update all models
async function updateAllModels() {
    for (const model of modelData) {
        await updateSingleModel(model.name);
    }
}

// Delete model
async function deleteModel(modelName) {
    if (!confirm(`Are you sure you want to delete "${modelName}"?`)) return;

    try {
        await fetch("/api/models/delete", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ model: modelName })
        });

        // Remove from local data
        modelData = modelData.filter(m => m.name !== modelName);
        renderModelCards();

        // Reload model selector
        loadModels();

        document.getElementById("modalFooterText").textContent = `"${modelName}" deleted successfully`;

    } catch (error) {
        console.error("Delete error:", error);
    }
}

// Poll for update status
function startUpdatePolling() {
    if (updatePolling) clearInterval(updatePolling);

    updatePolling = setInterval(async () => {
        try {
            const response = await fetch("/api/models/update-status");
            const statusData = await response.json();

            let allDone = true;

            modelData.forEach(model => {
                const status = statusData[model.name];
                if (status) {
                    model.update_checking = status.checking || false;
                    model.update_downloading = status.downloading || false;
                    model.update_progress = status.progress || 0;
                    model.update_error = status.error || null;
                    model.up_to_date = status.up_to_date || false;
                    model.updated = status.updated || false;

                    if (status.checking || status.downloading) {
                        allDone = false;
                    }
                }
            });

            renderModelCards();

            if (allDone) {
                clearInterval(updatePolling);
                updatePolling = null;

                const btn = document.getElementById("checkAllBtn");
                btn.disabled = false;
                btn.innerHTML = "🔄 Check All Updates";

                const updatedCount = modelData.filter(m => m.updated).length;
                const upToDateCount = modelData.filter(m => m.up_to_date).length;
                const errorCount = modelData.filter(m => m.update_error).length;

                let footerText = `✅ ${upToDateCount} up to date`;
                if (updatedCount > 0) footerText += ` | 🎉 ${updatedCount} updated`;
                if (errorCount > 0) footerText += ` | ❌ ${errorCount} errors`;

                document.getElementById("modalFooterText").textContent = footerText;

                // Reload models in selector
                loadModels();
            }

        } catch (error) {
            console.error("Polling error:", error);
        }
    }, 1000);
}

// Close modal on overlay click
document.getElementById("modelManagerModal")?.addEventListener("click", (e) => {
    if (e.target === document.getElementById("modelManagerModal")) {
        closeModelManager();
    }
});

// Close modal on Escape key
document.addEventListener("keydown", (e) => {
    if (e.key === "Escape") {
        closeModelManager();
    }
});