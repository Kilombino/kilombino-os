#!/bin/bash
# =============================================================================
# Kilombino OS — Setup Script
# Installs Ollama + Gemma 4 + Claude Code + Telegram Plugin on Ubuntu Server
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
echo -e "${GREEN}Instalando Ollama + Gemma 4 + Claude Code + Telegram...${NC}"
echo ""

# --- System update ---
echo -e "${ORANGE}[1/7] Actualizando sistema...${NC}"
sudo apt-get update -qq
sudo apt-get upgrade -y -qq
sudo apt-get install -y -qq tmux git curl

# --- Node.js LTS ---
echo -e "${ORANGE}[2/7] Instalando Node.js LTS...${NC}"
if ! command -v node &>/dev/null; then
  curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
  sudo apt-get install -y nodejs
fi
echo "  Node $(node --version), npm $(npm --version)"

# --- Claude Code ---
echo -e "${ORANGE}[3/7] Instalando Claude Code...${NC}"
if ! command -v claude &>/dev/null; then
  npm install -g @anthropic-ai/claude-code
fi
echo "  Claude Code instalado: $(claude --version 2>/dev/null || echo 'ok')"

# --- Claude Code Telegram Plugin ---
echo -e "${ORANGE}[4/7] Instalando plugin de Telegram para Claude Code...${NC}"
PLUGINS_DIR="$HOME/claude-plugins"
if [ ! -d "$PLUGINS_DIR" ]; then
  git clone https://github.com/anthropics/claude-code-plugins.git "$PLUGINS_DIR" 2>/dev/null || true
fi
echo "  Plugin de Telegram disponible"

# --- Ollama ---
echo -e "${ORANGE}[5/7] Instalando Ollama...${NC}"
if ! command -v ollama &>/dev/null; then
  curl -fsSL https://ollama.com/install.sh | sh
fi
sudo systemctl enable ollama
sudo systemctl start ollama
sleep 3
echo "  Ollama instalado: $(ollama --version)"

# --- Gemma 4 e4b ---
echo -e "${ORANGE}[6/7] Descargando modelo Gemma 4 e4b (~9.6 GB)...${NC}"
ollama pull gemma4:e4b
echo "  Gemma 4 e4b descargado"

# --- Configuración y autoarranque ---
echo -e "${ORANGE}[7/7] Configurando autoarranque...${NC}"
USER=$(whoami)

# Start script para Claude Code + Ollama + Telegram
cat > "$HOME/start-kilombino.sh" << 'STARTEOF'
#!/bin/bash
export PATH="/usr/local/bin:/usr/bin:/bin:$HOME/.npm-global/bin"
export HOME="$HOME"
export TMUX_TMPDIR="/tmp"

# Ollama env — Claude Code usará Ollama como backend
export ANTHROPIC_BASE_URL=http://localhost:11434
export ANTHROPIC_AUTH_TOKEN=ollama
export ANTHROPIC_API_KEY=""

PLUGINS_DIR="$HOME/claude-plugins"
LOG="$HOME/kilombino.log"

echo "[$(date)] Kilombino OS arrancando..." >> "$LOG"

# Wait for Ollama to be ready
for i in $(seq 1 30); do
  curl -s http://localhost:11434/api/tags >/dev/null 2>&1 && break
  sleep 2
done

if ! tmux -L kilombino has-session -t kilombino 2>/dev/null; then
    echo "[$(date)] Creando sesión Claude Code + Telegram" >> "$LOG"
    tmux -L kilombino new-session -d -s kilombino \
        "cd $HOME && claude --model gemma4:e4b --channels plugin:telegram@$PLUGINS_DIR --dangerously-skip-permissions 2>&1 | tee -a $LOG"
    sleep 5
    tmux -L kilombino send-keys -t kilombino Enter
    echo "[$(date)] Sesión creada" >> "$LOG"
else
    echo "[$(date)] Sesión ya existía" >> "$LOG"
fi
STARTEOF
chmod +x "$HOME/start-kilombino.sh"

# Fix HOME in the script (heredoc doesn't expand inside single quotes)
sed -i "s|\$HOME|$HOME|g" "$HOME/start-kilombino.sh"

# Crontab @reboot
(crontab -l 2>/dev/null | grep -v 'start-kilombino'; echo "@reboot sleep 15 && $HOME/start-kilombino.sh >> $HOME/kilombino.log 2>&1") | crontab -

# Sudo sin password
echo "$USER ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/$USER > /dev/null

# --- CLI helper ---
sudo tee /usr/local/bin/kilombino-os > /dev/null << 'CLIEOF'
#!/bin/bash
case "$1" in
  setup-telegram)
    echo ""
    echo "=== Configurar Bot de Telegram para Claude Code ==="
    echo ""
    echo "1. Abre Telegram y habla con @BotFather"
    echo "2. Escribe /newbot y sigue las instrucciones"
    echo "3. BotFather te dará un token. Pégalo aquí:"
    echo ""
    read -p "Bot Token: " TOKEN
    echo ""
    echo "Guardando token..."

    # Save bot token for the Telegram plugin
    TELEGRAM_DIR="$HOME/.claude/channels/telegram"
    mkdir -p "$TELEGRAM_DIR"
    cat > "$TELEGRAM_DIR/config.json" << CONF
{
  "bot_token": "$TOKEN"
}
CONF
    echo ""
    echo "4. Ahora abre tu bot en Telegram y escríbele algo"
    echo "   Claude Code (con Gemma 4) responderá automáticamente"
    echo ""
    echo "5. Para aprobar tu chat, ejecuta:"
    echo "   kilombino-os approve-telegram"
    echo ""
    echo "Reiniciando Claude Code..."
    tmux -L kilombino kill-session -t kilombino 2>/dev/null
    sleep 2
    "$HOME/start-kilombino.sh"
    echo ""
    echo "✅ Bot configurado y Claude Code reiniciado."
    ;;

  approve-telegram)
    echo "Ejecutando skill de acceso Telegram..."
    tmux -L kilombino send-keys -t kilombino "/telegram:access" Enter
    echo "Revisa la sesión de Claude Code: tmux -L kilombino attach -t kilombino"
    ;;

  attach)
    tmux -L kilombino attach -t kilombino
    ;;

  restart)
    echo "Reiniciando Claude Code..."
    tmux -L kilombino kill-session -t kilombino 2>/dev/null
    sleep 2
    "$HOME/start-kilombino.sh"
    echo "✅ Reiniciado."
    ;;

  status)
    echo "=== Kilombino OS Status ==="
    echo "Ollama:      $(systemctl is-active ollama)"
    echo "Claude Code: $(tmux -L kilombino has-session -t kilombino 2>/dev/null && echo 'running' || echo 'stopped')"
    echo "Modelo:      $(ollama list 2>/dev/null | grep gemma4 || echo 'no encontrado')"
    echo "Disco:       $(df -h / | tail -1)"
    echo "RAM:         $(free -h | grep Mem | awk '{print $3 "/" $2}')"
    ;;

  *)
    echo "Kilombino OS — Comandos disponibles:"
    echo "  kilombino-os setup-telegram    — Configurar bot de Telegram"
    echo "  kilombino-os approve-telegram  — Aprobar acceso Telegram"
    echo "  kilombino-os attach            — Ver consola de Claude Code"
    echo "  kilombino-os restart           — Reiniciar Claude Code"
    echo "  kilombino-os status            — Ver estado del sistema"
    ;;
esac
CLIEOF
sudo chmod +x /usr/local/bin/kilombino-os

# --- Branding ---
sudo hostnamectl set-hostname kilombino-os

sudo tee /etc/motd > /dev/null << 'MOTD'

  _  _ _ _                _    _               ___  ___
 | |/ (_) |___ _ __  | |__|(_)_ _  ___    / _ \/ __|
 | ' <| | / _ \ '  \ | '_ \ | ' \/ _ \  | (_) \__ \
 |_|\_\_|_\___/_|_|_||_.__/_|_||_\___/   \___/|___/

 Gemma 4 · Claude Code · Soberania Digital

 Comandos:
   kilombino-os setup-telegram    — Configurar Telegram
   kilombino-os approve-telegram  — Aprobar acceso
   kilombino-os attach            — Ver consola Claude Code
   kilombino-os restart           — Reiniciar
   kilombino-os status            — Ver estado

MOTD

echo ""
echo -e "${GREEN}${BOLD}=======================================${NC}"
echo -e "${GREEN}${BOLD}  Kilombino OS instalado con éxito!${NC}"
echo -e "${GREEN}${BOLD}=======================================${NC}"
echo ""
echo "Claude Code + Ollama + Gemma 4 + Plugin Telegram"
echo ""
echo "Siguiente paso: configurar tu bot de Telegram:"
echo ""
echo "  kilombino-os setup-telegram"
echo ""
echo "Después podrás hablar con Claude Code por Telegram,"
echo "con todas las herramientas (Read, Write, Edit, Bash)"
echo "alimentado por Gemma 4 corriendo 100% local."
echo ""
echo "Para ver la consola de Claude Code:"
echo "  kilombino-os attach"
echo ""
