/** Serves the chat web UI as inline HTML — no build step needed. */
export function renderUI(): Response {
  return new Response(HTML, {
    headers: { "Content-Type": "text/html; charset=utf-8" },
  });
}

const HTML = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Bot Fleet Chat</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      display: flex;
      height: 100vh;
      color: #1a1a1a;
    }

    /* ── Sidebar ── */
    .sidebar {
      width: 220px;
      background: #16213e;
      color: #c0c8d8;
      display: flex;
      flex-direction: column;
      flex-shrink: 0;
    }
    .sidebar-header {
      padding: 20px 16px 12px;
      font-size: 11px;
      font-weight: 600;
      text-transform: uppercase;
      letter-spacing: 1.5px;
      color: #6b7a94;
    }
    .bot-list {
      flex: 1;
      overflow-y: auto;
    }
    .bot-item {
      padding: 10px 16px;
      cursor: pointer;
      font-size: 13px;
      border-left: 3px solid transparent;
      transition: background 0.15s;
    }
    .bot-item:hover {
      background: rgba(255,255,255,0.05);
    }
    .bot-item.active {
      background: rgba(255,255,255,0.1);
      border-left-color: #5b9cf6;
      color: #fff;
    }
    .bot-item.broadcast {
      color: #f0c040;
      border-bottom: 1px solid rgba(255,255,255,0.06);
      margin-bottom: 4px;
    }

    /* ── Main area ── */
    .main {
      flex: 1;
      display: flex;
      flex-direction: column;
      background: #f7f8fa;
    }
    .chat-header {
      padding: 14px 20px;
      background: #fff;
      border-bottom: 1px solid #e4e6ea;
      font-size: 15px;
      font-weight: 600;
    }
    .chat-header .sub {
      font-size: 12px;
      font-weight: 400;
      color: #888;
      margin-top: 2px;
    }

    /* ── Messages ── */
    .messages {
      flex: 1;
      overflow-y: auto;
      padding: 20px;
      display: flex;
      flex-direction: column;
      gap: 8px;
    }
    .msg {
      max-width: 65%;
      padding: 10px 14px;
      border-radius: 12px;
      font-size: 14px;
      line-height: 1.45;
      white-space: pre-wrap;
      word-break: break-word;
    }
    .msg.from-human {
      background: #5b9cf6;
      color: #fff;
      align-self: flex-end;
      border-bottom-right-radius: 4px;
    }
    .msg.from-bot {
      background: #fff;
      border: 1px solid #e4e6ea;
      align-self: flex-start;
      border-bottom-left-radius: 4px;
    }
    .msg .time {
      font-size: 10px;
      margin-top: 4px;
      opacity: 0.6;
    }
    .msg.from-bot .sender {
      font-size: 11px;
      font-weight: 600;
      color: #5b9cf6;
      margin-bottom: 4px;
    }
    .empty-state {
      flex: 1;
      display: flex;
      align-items: center;
      justify-content: center;
      color: #aaa;
      font-size: 14px;
    }

    /* ── Input area ── */
    .input-area {
      padding: 12px 20px;
      background: #fff;
      border-top: 1px solid #e4e6ea;
      display: flex;
      gap: 8px;
    }
    .input-area textarea {
      flex: 1;
      padding: 10px 12px;
      border: 1px solid #ddd;
      border-radius: 8px;
      resize: none;
      font: inherit;
      font-size: 14px;
      line-height: 1.4;
      min-height: 40px;
      max-height: 120px;
    }
    .input-area textarea:focus {
      outline: none;
      border-color: #5b9cf6;
    }
    .input-area button {
      padding: 0 20px;
      background: #5b9cf6;
      color: #fff;
      border: none;
      border-radius: 8px;
      cursor: pointer;
      font: inherit;
      font-size: 14px;
      font-weight: 500;
    }
    .input-area button:hover { background: #4a8be5; }
    .input-area button:disabled { opacity: 0.5; cursor: default; }
  </style>
</head>
<body>
  <div class="sidebar">
    <div class="sidebar-header">Bot Fleet Chat</div>
    <div class="bot-list" id="bot-list"></div>
  </div>
  <div class="main">
    <div class="chat-header" id="chat-header">
      Select a bot to start chatting
    </div>
    <div class="messages" id="messages">
      <div class="empty-state">Select a bot from the sidebar</div>
    </div>
    <div class="input-area" id="input-area" style="display:none;">
      <textarea id="msg-input" placeholder="Type a message..." rows="1"></textarea>
      <button id="send-btn">Send</button>
    </div>
  </div>

<script>
  var BOTS = [
    "dispatch-bot"
  ];

  var selectedBot = null;
  var polling = null;

  // ── Build sidebar ──
  var botList = document.getElementById("bot-list");

  var bcItem = document.createElement("div");
  bcItem.className = "bot-item broadcast";
  bcItem.textContent = "Broadcast";
  bcItem.onclick = function() { selectBot("broadcast"); };
  botList.appendChild(bcItem);

  BOTS.forEach(function(bot) {
    var item = document.createElement("div");
    item.className = "bot-item";
    item.id = "bot-" + bot;
    item.textContent = bot;
    item.onclick = function() { selectBot(bot); };
    botList.appendChild(item);
  });

  // ── Select a bot ──
  function selectBot(bot) {
    selectedBot = bot;

    // Update active state
    var items = document.querySelectorAll(".bot-item");
    for (var i = 0; i < items.length; i++) items[i].classList.remove("active");

    if (bot === "broadcast") {
      bcItem.classList.add("active");
    } else {
      document.getElementById("bot-" + bot).classList.add("active");
    }

    // Update header
    var header = document.getElementById("chat-header");
    if (bot === "broadcast") {
      header.innerHTML = 'Broadcast<div class="sub">Send a message to all bots</div>';
    } else {
      header.textContent = bot;
    }

    // Show input
    document.getElementById("input-area").style.display = "flex";
    document.getElementById("msg-input").focus();

    // Load messages
    loadMessages();

    // Poll every 5s for new messages (not for broadcast view)
    if (polling) clearInterval(polling);
    if (bot !== "broadcast") {
      polling = setInterval(loadMessages, 5000);
    }
  }

  // ── Load messages ──
  function loadMessages() {
    if (!selectedBot) return;

    if (selectedBot === "broadcast") {
      document.getElementById("messages").innerHTML =
        '<div class="empty-state">Messages will be sent to all ' + BOTS.length + ' bots</div>';
      return;
    }

    fetch("/api/messages?bot=" + encodeURIComponent(selectedBot))
      .then(function(res) { return res.json(); })
      .then(function(data) {
        var container = document.getElementById("messages");

        if (!data.messages || data.messages.length === 0) {
          container.innerHTML = '<div class="empty-state">No messages yet. Start the conversation!</div>';
          return;
        }

        var wasAtBottom = container.scrollHeight - container.scrollTop - container.clientHeight < 40;

        container.innerHTML = data.messages.map(function(m) {
          var isHuman = m.from === "human";
          var time = new Date(m.timestamp).toLocaleString();
          var cls = isHuman ? "from-human" : "from-bot";
          var html = '<div class="msg ' + cls + '">';
          if (!isHuman) html += '<div class="sender">' + esc(m.from) + '</div>';
          html += esc(m.body);
          html += '<div class="time">' + time + '</div>';
          html += '</div>';
          return html;
        }).join("");

        if (wasAtBottom) container.scrollTop = container.scrollHeight;
      })
      .catch(function(err) { console.error("Failed to load messages:", err); });
  }

  // ── Send message ──
  function sendMessage() {
    if (!selectedBot) return;

    var input = document.getElementById("msg-input");
    var body = input.value.trim();
    if (!body) return;

    var btn = document.getElementById("send-btn");
    btn.disabled = true;

    fetch("/api/messages", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ to: selectedBot, body: body })
    })
    .then(function(res) {
      if (res.ok) {
        input.value = "";
        input.style.height = "auto";
        if (selectedBot === "broadcast") {
          document.getElementById("messages").innerHTML =
            '<div class="empty-state">Message broadcast to all ' + BOTS.length + ' bots</div>';
        } else {
          loadMessages();
        }
      }
    })
    .catch(function(err) { console.error("Failed to send:", err); })
    .then(function() { btn.disabled = false; });
  }

  function esc(str) {
    var d = document.createElement("div");
    d.textContent = str;
    return d.innerHTML;
  }

  // ── Event listeners ──
  document.getElementById("send-btn").onclick = sendMessage;

  var msgInput = document.getElementById("msg-input");
  msgInput.addEventListener("input", function() {
    this.style.height = "auto";
    this.style.height = Math.min(this.scrollHeight, 120) + "px";
  });
  msgInput.addEventListener("keydown", function(e) {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      sendMessage();
    }
  });
</script>
</body>
</html>`;
