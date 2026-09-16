---
name: telegram
description: Send Telegram messages and file attachments through a configured bot. Use when the user asks to notify, message, or deliver a file via Telegram.
---

# Telegram

Use the Telegram Bot API directly with `curl`. The setup does not install a
separate harness.

## Credentials

The bot token and default destination are in:

```bash
${XDG_CONFIG_HOME:-$HOME/.config}/telegram/bot.env
```

Load them without printing either value:

```bash
telegram_config="${XDG_CONFIG_HOME:-$HOME/.config}/telegram/bot.env"
[ -r "$telegram_config" ] || {
  printf 'Telegram is not configured. Run ~/.dotfiles/telegram.sh first.\n' >&2
  exit 1
}
# shellcheck disable=SC1090
. "$telegram_config"
: "${TELEGRAM_BOT_TOKEN:?Telegram bot token is not configured}"
: "${TELEGRAM_CHAT_ID:?Telegram chat ID is not configured}"
telegram_api="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}"
```

Never display, log, commit, or include `TELEGRAM_BOT_TOKEN` in a response.
Treat the configured chat as an external destination: before sending, ensure
the user's request authorizes the message, attachment, and their contents.

## Send text

Use `--data-urlencode` so spaces and special characters are preserved:

```bash
message='Task completed successfully.'
curl -fsS \
  --data-urlencode "chat_id=$TELEGRAM_CHAT_ID" \
  --data-urlencode "text=$message" \
  "$telegram_api/sendMessage"
```

## Send a file attachment

Use `sendDocument` for a general file. Verify the path and intended contents
before uploading it.

```bash
file='/absolute/path/to/report.pdf'
caption='Requested report'
[ -f "$file" ] || { printf 'File not found: %s\n' "$file" >&2; exit 1; }
curl -fsS \
  -F "chat_id=$TELEGRAM_CHAT_ID" \
  -F "document=@$file" \
  -F "caption=$caption" \
  "$telegram_api/sendDocument"
```

Telegram returns JSON. Regard the operation as successful only when the
response contains `"ok":true`; otherwise report the API error without exposing
the request URL or token.
