#!/bin/bash
# =============================================================================
# Kilombino OS — Setup Script
# Installs Ollama + Gemma 4 + Telegram Bot on Ubuntu Server 24.04
# Usage: curl -sL https://raw.githubusercontent.com/Kilombino/kilombino-os/main/setup.sh | bash
# =============================================================================

set -e

BOLD='\033[1m'
ORANGE='\033[38;5;208m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${ORANGE}${BOLD}"
echo "  _  _ _ _                _    _               ___  ___"
echo " | |/ (_) |___ _ __  | |__(_)_ _  ___    / _ \\/ __|"
echo " | ' <| | / _ \\ '  \\ | '_ \\ | ' \\/ _ \\  | (_) \\__ \\"
echo " |_|\\_\\_|_\\___/_|_|_||_.__/_|_||_\\___/   \\___/|___/"
echo -e "${NC}"
echo -e "${GREEN}Instalando Ollama + Gemma 4 + Telegram Bot...${NC}"
echo ""

# --- System update ---
echo -e "${ORANGE}[1/7] Actualizando sistema...${NC}"
sudo apt-get update -qq
sudo apt-get upgrade -y -qq

# --- Node.js LTS ---
echo -e "${ORANGE}[2/7] Instalando Node.js LTS...${NC}"
if ! command -v node &>/dev/null; then
  curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
  sudo apt-get install -y nodejs
fi
echo "  Node $(node --version), npm $(npm --version)"

# --- Ollama ---
echo -e "${ORANGE}[3/7] Instalando Ollama...${NC}"
if ! command -v ollama &>/dev/null; then
  curl -fsSL https://ollama.com/install.sh | sh
fi
# Start ollama service
sudo systemctl enable ollama
sudo systemctl start ollama
sleep 3
echo "  Ollama instalado: $(ollama --version)"

# --- Gemma 4 e4b ---
echo -e "${ORANGE}[4/7] Descargando modelo Gemma 4 e4b (~9.6 GB)...${NC}"
ollama pull gemma4:e4b
echo "  Gemma 4 e4b descargado"

# --- Bot de Telegram ---
echo -e "${ORANGE}[5/7] Instalando bot de Telegram...${NC}"
BOTDIR="$HOME/kilombino-bot"
mkdir -p "$BOTDIR"

# package.json
cat > "$BOTDIR/package.json" << 'PKGJSON'
{
  "name": "kilombino-bot",
  "version": "1.0.0",
  "private": true,
  "dependencies": {
    "node-telegram-bot-api": "^0.66.0"
  }
}
PKGJSON

cd "$BOTDIR" && npm install --no-audit --no-fund --loglevel=error

# Bot source
cat > "$BOTDIR/bot.js" << 'BOTJS'
const TelegramBot = require('node-telegram-bot-api');
const { execSync, exec } = require('child_process');
const fs = require('fs');
const path = require('path');

// --- Config ---
const CONFIG_FILE = path.join(__dirname, 'config.json');
if (!fs.existsSync(CONFIG_FILE)) {
  console.error('Config not found. Run: kilombino-os setup-telegram');
  process.exit(1);
}
const config = JSON.parse(fs.readFileSync(CONFIG_FILE, 'utf8'));
const BOT_TOKEN = config.bot_token;
const ALLOWED_USERS = config.allowed_users || []; // chat_ids allowed to use the bot
const MODEL = config.model || 'gemma4:e4b';
const OLLAMA_URL = config.ollama_url || 'http://localhost:11434';

const bot = new TelegramBot(BOT_TOKEN, { polling: true });

// --- Conversation history (per chat) ---
const conversations = new Map();
const HISTORY_DIR = path.join(__dirname, 'history');
if (!fs.existsSync(HISTORY_DIR)) fs.mkdirSync(HISTORY_DIR);

function getHistory(chatId) {
  if (conversations.has(chatId)) return conversations.get(chatId);
  const file = path.join(HISTORY_DIR, `${chatId}.json`);
  let hist = [];
  try { hist = JSON.parse(fs.readFileSync(file, 'utf8')); } catch {}
  conversations.set(chatId, hist);
  return hist;
}

function saveHistory(chatId) {
  const file = path.join(HISTORY_DIR, `${chatId}.json`);
  fs.writeFileSync(file, JSON.stringify(getHistory(chatId).slice(-50)));
}

// --- Ollama API ---
async function chat(chatId, userMessage) {
  const history = getHistory(chatId);
  history.push({ role: 'user', content: userMessage });

  const systemPrompt = `Eres un asistente técnico corriendo en Kilombino OS. Puedes ayudar con Bitcoin, Linux, redes, programación y tareas del sistema.

Cuando el usuario te pida ejecutar un comando, responde EXACTAMENTE con este formato:
[EXEC] comando aquí

Por ejemplo:
- Usuario: "Qué espacio tengo en disco?" → [EXEC] df -h
- Usuario: "Instala htop" → [EXEC] sudo apt install -y htop
- Usuario: "Cuánta RAM tengo?" → [EXEC] free -h

Si no necesitas ejecutar nada, responde normalmente en texto.
Si el comando puede ser peligroso (rm -rf /, formatear disco, etc.), advierte al usuario antes.
Responde en el idioma del usuario (español si te hablan en español).`;

  const messages = [
    { role: 'system', content: systemPrompt },
    ...history.slice(-20) // last 20 messages for context
  ];

  try {
    const res = await fetch(`${OLLAMA_URL}/api/chat`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ model: MODEL, messages, stream: false }),
    });
    const data = await res.json();
    const reply = data.message?.content || 'Sin respuesta del modelo.';
    history.push({ role: 'assistant', content: reply });
    saveHistory(chatId);
    return reply;
  } catch(e) {
    return `Error conectando con Ollama: ${e.message}`;
  }
}

// --- Execute command ---
function executeCommand(cmd, timeout = 30000) {
  return new Promise((resolve) => {
    exec(cmd, { timeout, maxBuffer: 1024 * 1024 }, (err, stdout, stderr) => {
      if (err) {
        resolve(`Error (code ${err.code}):\n${stderr || err.message}`.slice(0, 4000));
      } else {
        resolve((stdout || stderr || '(sin output)').slice(0, 4000));
      }
    });
  });
}

// --- Message handler ---
bot.on('message', async (msg) => {
  const chatId = msg.chat.id;

  // Access control
  if (ALLOWED_USERS.length > 0 && !ALLOWED_USERS.includes(chatId)) {
    return bot.sendMessage(chatId, `No autorizado. Tu chat_id es: ${chatId}\nPide al admin que te añada.`);
  }

  const text = msg.text;
  if (!text) return;

  // /start command
  if (text === '/start') {
    return bot.sendMessage(chatId, `🟠 Kilombino OS Bot\n\nTu chat_id: ${chatId}\n\nEscríbeme lo que necesites. Puedo:\n- Responder preguntas\n- Ejecutar comandos del sistema\n- Ayudarte con Bitcoin, Linux, etc.\n\nModelo: ${MODEL}`);
  }

  // /clear command
  if (text === '/clear') {
    conversations.delete(chatId);
    const file = path.join(HISTORY_DIR, `${chatId}.json`);
    try { fs.unlinkSync(file); } catch {}
    return bot.sendMessage(chatId, 'Historial borrado.');
  }

  // Send "typing" indicator
  bot.sendChatAction(chatId, 'typing');

  // Get AI response
  const reply = await chat(chatId, text);

  // Check if reply contains a command to execute
  const execMatch = reply.match(/\[EXEC\]\s*(.+)/);
  if (execMatch) {
    const cmd = execMatch[1].trim();
    await bot.sendMessage(chatId, `⚙️ Ejecutando: \`${cmd}\``, { parse_mode: 'Markdown' });
    bot.sendChatAction(chatId, 'typing');
    const output = await executeCommand(cmd);
    await bot.sendMessage(chatId, `📟 Output:\n\`\`\`\n${output}\n\`\`\``, { parse_mode: 'Markdown' });

    // Feed the output back to the model for analysis
    const analysis = await chat(chatId, `El comando "${cmd}" ha devuelto:\n${output}\n\nExplica brevemente el resultado.`);
    await bot.sendMessage(chatId, analysis);
  } else {
    // Split long messages (Telegram limit 4096 chars)
    const chunks = reply.match(/[\s\S]{1,4000}/g) || [reply];
    for (const chunk of chunks) {
      await bot.sendMessage(chatId, chunk);
    }
  }
});

console.log(`[Kilombino Bot] Running with model ${MODEL}`);
console.log(`[Kilombino Bot] Allowed users: ${ALLOWED_USERS.length > 0 ? ALLOWED_USERS.join(', ') : 'ALL (no restriction)'}`);
BOTJS

echo "  Bot instalado en $BOTDIR"

# --- Setup Telegram helper script ---
echo -e "${ORANGE}[6/7] Configurando herramientas...${NC}"
sudo tee /usr/local/bin/kilombino-os > /dev/null << 'CLIEOF'
#!/bin/bash
case "$1" in
  setup-telegram)
    BOTDIR="$HOME/kilombino-bot"
    echo ""
    echo "=== Configurar Bot de Telegram ==="
    echo ""
    echo "1. Abre Telegram y habla con @BotFather"
    echo "2. Escribe /newbot y sigue las instrucciones"
    echo "3. BotFather te dará un token. Pégalo aquí:"
    echo ""
    read -p "Bot Token: " TOKEN
    echo ""
    echo "4. Ahora abre tu bot en Telegram y escríbele /start"
    echo "5. El bot te dirá tu chat_id. Pégalo aquí:"
    echo ""
    read -p "Tu chat_id: " CHATID
    echo ""

    cat > "$BOTDIR/config.json" << CONF
{
  "bot_token": "$TOKEN",
  "allowed_users": [$CHATID],
  "model": "gemma4:e4b",
  "ollama_url": "http://localhost:11434"
}
CONF

    # Enable and start the service
    sudo systemctl restart kilombino-bot
    echo ""
    echo "✅ Bot configurado y arrancado."
    echo "Escríbele algo a tu bot en Telegram — debería responder."
    ;;

  add-user)
    BOTDIR="$HOME/kilombino-bot"
    read -p "Chat ID del nuevo usuario: " NEWID
    node -e "
      const f = '$BOTDIR/config.json';
      const c = JSON.parse(require('fs').readFileSync(f));
      if (!c.allowed_users.includes($NEWID)) c.allowed_users.push($NEWID);
      require('fs').writeFileSync(f, JSON.stringify(c, null, 2));
      console.log('Usuarios permitidos:', c.allowed_users);
    "
    sudo systemctl restart kilombino-bot
    echo "✅ Usuario añadido y bot reiniciado."
    ;;

  status)
    echo "=== Kilombino OS Status ==="
    echo "Ollama: $(systemctl is-active ollama)"
    echo "Bot:    $(systemctl is-active kilombino-bot)"
    echo "Modelo: $(ollama list 2>/dev/null | grep gemma || echo 'no encontrado')"
    echo "Disco:  $(df -h / | tail -1)"
    echo "RAM:    $(free -h | grep Mem | awk '{print $3 "/" $2}')"
    ;;

  *)
    echo "Kilombino OS — Comandos disponibles:"
    echo "  kilombino-os setup-telegram  — Configurar bot de Telegram"
    echo "  kilombino-os add-user        — Añadir usuario autorizado"
    echo "  kilombino-os status          — Ver estado del sistema"
    ;;
esac
CLIEOF
sudo chmod +x /usr/local/bin/kilombino-os

# --- Systemd services ---
echo -e "${ORANGE}[7/7] Configurando autoarranque...${NC}"
BOTDIR="$HOME/kilombino-bot"
USER=$(whoami)

sudo tee /etc/systemd/system/kilombino-bot.service > /dev/null << SVCEOF
[Unit]
Description=Kilombino OS Telegram Bot
After=network-online.target ollama.service
Wants=network-online.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$BOTDIR
ExecStart=$(which node) bot.js
Restart=always
RestartSec=5
Environment=HOME=$HOME

[Install]
WantedBy=multi-user.target
SVCEOF

sudo systemctl daemon-reload
sudo systemctl enable kilombino-bot

# --- Branding ---
sudo hostnamectl set-hostname kilombino-os

sudo tee /etc/motd > /dev/null << 'MOTD'

  _  _ _ _                _    _               ___  ___
 | |/ (_) |___ _ __  | |__|(_)_ _  ___    / _ \/ __|
 | ' <| | / _ \ '  \ | '_ \ | ' \/ _ \  | (_) \__ \
 |_|\_\_|_\___/_|_|_||_.__/_|_||_\___/   \___/|___/

 Bitcoin · Gemma 4 · Soberania Digital

 Comandos:
   kilombino-os status          — Ver estado
   kilombino-os setup-telegram  — Configurar Telegram
   kilombino-os add-user        — Añadir usuario

MOTD

echo ""
echo -e "${GREEN}${BOLD}=======================================${NC}"
echo -e "${GREEN}${BOLD}  Kilombino OS instalado con éxito!${NC}"
echo -e "${GREEN}${BOLD}=======================================${NC}"
echo ""
echo "Siguiente paso: configurar tu bot de Telegram:"
echo ""
echo "  kilombino-os setup-telegram"
echo ""
echo "Esto te pedirá el token de @BotFather y tu chat_id."
echo "Después podrás hablar con tu asistente IA por Telegram."
echo ""
