# Kilombino OS

**Gemma 4 · Claude Code · Soberanía Digital**

Script de instalación que convierte cualquier mini PC x86 con Ubuntu Server en un asistente IA local con Claude Code, accesible por Telegram.

## Qué incluye

- **Claude Code** — el CLI de Anthropic con todas sus herramientas (Read, Write, Edit, Bash, etc.)
- **Ollama** — servidor de modelos IA local
- **Gemma 4 e4b** — modelo de Google, gratuito y open source (4.5B params, 128K contexto, multimodal)
- **Plugin Telegram** — habla con Claude Code desde el móvil, exactamente como hablar con Claude
- **Ejecución de comandos** — Claude Code ejecuta comandos en el sistema con permisos completos
- **Autoarranque** — todo levanta solo al encender (tmux + crontab @reboot)
- **100% local** — el modelo corre en tu hardware, nada en la nube, coste cero

## Cómo funciona

Claude Code se conecta a Ollama (que sirve Gemma 4 localmente) en vez de a la API de Anthropic. Así tienes todas las herramientas y capacidades de Claude Code pero alimentadas por un modelo gratuito y soberano.

## Instalación

### Paso 1 — Instalar Ubuntu Server 24.04

1. Descarga la ISO de [ubuntu.com/download/server](https://ubuntu.com/download/server)
2. Grábala en un USB con [Rufus](https://rufus.ie/)
3. Arranca el mini PC desde el USB
4. Sigue el instalador: idioma → teclado → usuario/contraseña → instalar
5. Reinicia y entra con tu usuario

### Paso 2 — Ejecutar el script

```bash
curl -sL https://raw.githubusercontent.com/Kilombino/kilombino-os/main/setup.sh | bash
```

Instala automáticamente (~20 min):
- Node.js LTS + Claude Code
- Plugin Telegram para Claude Code
- Ollama + Gemma 4 e4b (~9.6 GB)
- Autoarranque con tmux + crontab
- Sudo sin password
- Branding Kilombino OS

### Paso 3 — Configurar Telegram

```bash
kilombino-os setup-telegram
```

1. Abre Telegram → habla con [@BotFather](https://t.me/BotFather)
2. Escribe `/newbot` → ponle nombre → copia el **token**
3. Pega el token cuando el script te lo pida
4. Abre tu bot y escríbele algo
5. Aprueba el acceso: `kilombino-os approve-telegram`

## Comandos

```bash
kilombino-os setup-telegram    # Configurar bot de Telegram
kilombino-os approve-telegram  # Aprobar acceso Telegram
kilombino-os attach            # Ver consola de Claude Code en directo
kilombino-os restart           # Reiniciar Claude Code
kilombino-os status            # Ver estado del sistema
```

## Requisitos

| Componente | Mínimo | Recomendado |
|-----------|--------|-------------|
| CPU | x86_64 dual-core | Intel i5 / AMD Ryzen 5 |
| RAM | 8 GB | 16 GB |
| Disco | 25 GB libres | 50 GB SSD |
| Internet | Para instalación + Telegram | — |
| SO | Ubuntu Server 24.04 LTS | — |

## Arquitectura

```
Telegram → Plugin Telegram → Claude Code → Ollama → Gemma 4 (local)
                                  ↓
                          Read / Write / Edit / Bash
                          (herramientas del sistema)
```

## Licencia

MIT
