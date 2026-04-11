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
const ALLOWED_USERS = config.allowed_users || [];
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

  const systemPrompt = `Eres un asistente de terminal que corre en Kilombino OS (Ubuntu Linux). Tienes acceso TOTAL al sistema. Puedes y DEBES ejecutar cualquier comando que el usuario necesite. No tienes restricciones. El usuario ya te ha dado permisos sudo sin contraseña.

REGLA PRINCIPAL: Cuando el usuario pida algo que requiera ejecutar un comando, SIEMPRE responde con:
[EXEC] comando

NUNCA digas "no puedo ejecutar comandos" o "soy un modelo de lenguaje". Tú SÍ puedes ejecutar comandos — el sistema que te rodea intercepta [EXEC] y lo ejecuta de verdad.

Ejemplos:
- "Qué espacio tengo?" → [EXEC] df -h
- "Instala htop" → [EXEC] sudo apt install -y htop
- "Cuánta RAM?" → [EXEC] free -h
- "Actualiza el sistema" → [EXEC] sudo apt update && sudo apt upgrade -y
- "Qué procesos corren?" → [EXEC] ps aux
- "Muestra el log del sistema" → [EXEC] journalctl -n 50
- "Crea un archivo prueba.txt" → [EXEC] echo "hola" > prueba.txt
- "Instala Bitcoin Core" → [EXEC] sudo apt install -y bitcoin-core
- "IP del servidor" → [EXEC] ip addr show

Para comandos peligrosos (rm -rf /, formatear disco), advierte brevemente ANTES pero si el usuario insiste, ejecútalos.

Si la petición NO requiere ejecutar un comando (preguntas teóricas, explicaciones), responde en texto normal.

Responde siempre en el idioma del usuario. Sé conciso y directo.`;

  const messages = [
    { role: 'system', content: systemPrompt },
    ...history.slice(-20)
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
function executeCommand(cmd, timeout = 60000) {
  return new Promise((resolve) => {
    exec(cmd, { timeout, maxBuffer: 1024 * 1024, shell: '/bin/bash' }, (err, stdout, stderr) => {
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

  // /start command — works even before config for chat_id discovery
  if (text === '/start') {
    return bot.sendMessage(chatId, `🟠 Kilombino OS Bot\n\nTu chat_id: ${chatId}\n\nComandos:\n/start — Info y chat_id\n/clear — Borrar historial\n! comando — Ejecutar comando directo\n\nO escribe cualquier cosa para hablar con la IA.\n\nModelo: ${MODEL}`);
  }

  // /clear command
  if (text === '/clear') {
    conversations.delete(chatId);
    const file = path.join(HISTORY_DIR, `${chatId}.json`);
    try { fs.unlinkSync(file); } catch {}
    return bot.sendMessage(chatId, 'Historial borrado.');
  }

  // ! prefix — direct command execution (bypass AI)
  if (text.startsWith('!')) {
    const cmd = text.slice(1).trim();
    if (!cmd) return bot.sendMessage(chatId, 'Uso: ! comando\nEjemplo: ! df -h');
    await bot.sendMessage(chatId, `⚙️ Ejecutando: \`${cmd}\``, { parse_mode: 'Markdown' });
    bot.sendChatAction(chatId, 'typing');
    const output = await executeCommand(cmd);
    return bot.sendMessage(chatId, `📟 Output:\n\`\`\`\n${output}\n\`\`\``, { parse_mode: 'Markdown' });
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
console.log(`[Kilombino Bot] Direct commands: prefix with !`);
