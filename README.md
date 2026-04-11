# Kilombino OS

**Bitcoin · Gemma 4 · Soberanía Digital**

Script de instalación que convierte cualquier mini PC x86 con Ubuntu Server 24.04 en un asistente IA local accesible por Telegram.

## Qué incluye

- **Ollama** — servidor de modelos IA local
- **Gemma 4 e4b** — modelo de Google, gratuito y open source (4.5B params, 128K contexto, multimodal)
- **Bot de Telegram** — habla con tu IA desde el móvil
- **Ejecución de comandos** — el bot puede ejecutar comandos en el sistema
- **Autoarranque** — todo levanta solo al encender
- **Persistencia** — historial de conversaciones guardado en local

## Instalación

### Paso 1 — Instalar Ubuntu Server 24.04

1. Descarga la ISO de [ubuntu.com/download/server](https://ubuntu.com/download/server)
2. Grábala en un USB con [Balena Etcher](https://etcher.balena.io/)
3. Arranca el mini PC desde el USB
4. Sigue el instalador: idioma → teclado → usuario/contraseña → instalar
5. Reinicia y entra con tu usuario

### Paso 2 — Ejecutar el script

```bash
curl -sL https://raw.githubusercontent.com/Kilombino/kilombino-os/main/setup.sh | bash
```

Esto instala automáticamente (~15-20 min según velocidad de internet):
- Node.js LTS
- Ollama
- Gemma 4 e4b (~9.6 GB de descarga)
- Bot de Telegram
- Servicios de autoarranque
- Branding Kilombino OS

### Paso 3 — Configurar Telegram

```bash
kilombino-os setup-telegram
```

El script te guiará:
1. Abre Telegram → habla con [@BotFather](https://t.me/BotFather)
2. Escribe `/newbot` → ponle nombre → copia el **token**
3. Abre tu nuevo bot en Telegram y escríbele `/start`
4. El bot te dirá tu **chat_id**
5. Pega token y chat_id cuando el script te lo pida
6. ¡Listo! Ya puedes hablar con tu IA por Telegram

## Uso

Escribe a tu bot de Telegram y responderá usando Gemma 4 local:

- **Preguntas normales** → responde con IA
- **Pedir ejecutar comandos** → ejecuta en el sistema y devuelve el resultado
- `/clear` → borra historial de conversación
- `/start` → muestra info del bot

## Comandos de administración

```bash
kilombino-os status          # Ver estado del sistema (ollama, bot, disco, RAM)
kilombino-os setup-telegram  # Configurar o reconfigurar el bot
kilombino-os add-user        # Autorizar a otro usuario (chat_id)
```

## Requisitos

| Componente | Mínimo | Recomendado |
|-----------|--------|-------------|
| CPU | x86_64 dual-core | Intel i5 / AMD Ryzen 5 |
| RAM | 8 GB | 16 GB |
| Disco | 20 GB libres | 40 GB SSD |
| Internet | Necesario para instalación | Necesario para Telegram |
| SO | Ubuntu Server 24.04 LTS | — |

## Seguridad

- Solo los chat_ids autorizados pueden hablar con el bot
- Los no autorizados reciben su chat_id para que el admin los añada
- Todo corre local — el modelo no envía datos a ningún servidor externo
- El historial de conversaciones se guarda solo en el mini PC

## Licencia

MIT
