# Kilombino OS

**Bitcoin · Gemma 3 · Soberanía Digital**

Script de instalación que convierte cualquier mini PC x86 con Ubuntu Server 24.04 en un asistente IA local accesible por Telegram.

## Qué incluye

- **Ollama** — servidor de modelos IA local
- **Gemma 3 4B** — modelo de Google, gratuito y open source
- **Bot de Telegram** — habla con tu IA desde el móvil
- **Ejecución de comandos** — el bot puede ejecutar comandos en el sistema
- **Autoarranque** — todo levanta solo al encender
- **Persistencia** — historial de conversaciones guardado en local

## Instalación

En un Ubuntu Server 24.04 recién instalado:

```bash
curl -sL https://raw.githubusercontent.com/Kilombino/kilombino-os/main/setup.sh | bash
```

Después configurar Telegram:

```bash
kilombino-os setup-telegram
```

## Requisitos

- Mini PC x86 (Intel/AMD)
- 8 GB RAM mínimo (16 GB recomendado)
- 20 GB disco libre
- Conexión a internet (para la instalación)
- Ubuntu Server 24.04 LTS

## Comandos

```bash
kilombino-os status          # Ver estado del sistema
kilombino-os setup-telegram  # Configurar bot de Telegram
kilombino-os add-user        # Añadir usuario autorizado
```

## Flujo de uso

1. Instalar Ubuntu Server 24.04 en el mini PC
2. Ejecutar el script de instalación
3. Configurar el bot de Telegram con @BotFather
4. Hablar con tu IA desde Telegram

## Licencia

MIT
