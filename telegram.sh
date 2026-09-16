#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
skill_source="$repo_dir/skills/telegram"
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/telegram"
config_file="$config_dir/bot.env"
codex_skill="${CODEX_HOME:-$HOME/.codex}/skills/telegram"
pi_skill="$HOME/.pi/agent/skills/telegram"

die() {
  printf 'エラー: %s\n' "$*" >&2
  exit 1
}

command -v curl >/dev/null 2>&1 || die 'curl が必要です'
[ -f "$skill_source/SKILL.md" ] || die "$skill_source/SKILL.md がありません"

existing_token=''
existing_chat_id=''
if [ -r "$config_file" ]; then
  existing_token=$(sed -n 's/^TELEGRAM_BOT_TOKEN=//p' "$config_file" | tail -n 1)
  existing_chat_id=$(sed -n 's/^TELEGRAM_CHAT_ID=//p' "$config_file" | tail -n 1)
fi

if [ -n "$existing_token" ]; then
  printf '既存のTelegram bot tokenがあります。Enterで現在の値を維持します。\n'
fi
printf 'Telegram bot token: '
IFS= read -r -s entered_token
printf '\n'
if [ -n "$entered_token" ]; then
  bot_token=$entered_token
else
  bot_token=$existing_token
fi
[ -n "$bot_token" ] || die 'bot tokenを入力してください'
case "$bot_token" in
  *:*) ;;
  *) die 'bot tokenの形式が不正です' ;;
esac
token_prefix=${bot_token%%:*}
token_secret=${bot_token#*:}
case "$token_prefix" in
  ''|*[!0-9]*) die 'bot tokenの形式が不正です' ;;
esac
case "$token_secret" in
  ''|*[!0-9A-Za-z_-]*) die 'bot tokenの形式が不正です' ;;
esac

api_base="https://api.telegram.org/bot${bot_token}"
get_me_response=$(curl -fsS --connect-timeout 10 --max-time 30 \
  "$api_base/getMe") || die 'Telegram APIへ接続できませんでした'
case "$get_me_response" in
  *'"ok":true'*) ;;
  *) die 'bot tokenをTelegram APIで確認できませんでした' ;;
esac
printf 'bot tokenを確認しました。\n'

if [ -n "$existing_chat_id" ]; then
  printf 'Chat ID [%s] (Enterで維持、自動取得は auto): ' "$existing_chat_id"
else
  printf 'Chat ID (自動取得はEnter): '
fi
IFS= read -r entered_chat_id

case "$entered_chat_id" in
  '') chat_id=$existing_chat_id ;;
  auto) chat_id='' ;;
  *) chat_id=$entered_chat_id ;;
esac

valid_chat_id() {
  candidate_chat_id=$1
  case "$candidate_chat_id" in
    -*) candidate_chat_id=${candidate_chat_id#-} ;;
  esac
  case "$candidate_chat_id" in
    ''|*[!0-9]*) return 1 ;;
    *) return 0 ;;
  esac
}

if [ -n "$chat_id" ] && ! valid_chat_id "$chat_id"; then
  die 'chat_idは整数で入力してください'
fi

if [ -z "$chat_id" ]; then
  printf '%s\n' \
    'Telegramでこのbotとのチャットを開き、/start などのメッセージを送信してください。' \
    '送信後にEnterを押すと、getUpdatesから最新のchat_idを取得します。'

  while [ -z "$chat_id" ]; do
    printf 'Enterで取得を試行（chat_idを直接入力することもできます）: '
    IFS= read -r retry_value
    if [ -n "$retry_value" ]; then
      valid_chat_id "$retry_value" || die 'chat_idは整数で入力してください'
      chat_id=$retry_value
      break
    fi

    updates_response=$(curl -fsS --connect-timeout 10 --max-time 30 \
      "$api_base/getUpdates") || die 'Telegram APIへ接続できませんでした'
    case "$updates_response" in
      *'"ok":false'*)
        error_description=$(printf '%s\n' "$updates_response" |
          sed -n 's/.*"description":"\([^"]*\)".*/\1/p')
        die "getUpdatesに失敗しました: ${error_description:-詳細不明}"
        ;;
    esac

    detected_ids=$(printf '%s\n' "$updates_response" |
      tr -d '\n\r\t ' |
      sed 's/"chat":{"id":/\
&/g' |
      sed -n 's/^"chat":{"id":\(-\{0,1\}[0-9][0-9]*\).*/\1/p' |
      awk '!seen[$0]++')
    detected_chat_id=$(printf '%s\n' "$detected_ids" | sed '/^$/d' | tail -n 1)

    if [ -n "$detected_chat_id" ]; then
      chat_id=$detected_chat_id
      printf '最新のchat_id %s を使用します。\n' "$chat_id"
    else
      printf 'chat_idを取得できませんでした。botへメッセージを送ってから再試行してください。\n'
    fi
  done
fi

link_skill() {
  target=$1
  target_parent=${target%/*}
  mkdir -p "$target_parent"

  if [ -L "$target" ] && [ "$skill_source" -ef "$target" ]; then
    printf '%s は設定済みです。\n' "$target"
    return
  fi
  if [ -e "$target" ] || [ -L "$target" ]; then
    die "$target が既に存在し、管理対象のtelegramスキルではありません"
  fi
  ln -s "$skill_source" "$target"
  printf '%s を作成しました。\n' "$target"
}

mkdir -p "$config_dir"
chmod 0700 "$config_dir"
temporary_config=$(mktemp "$config_dir/.bot.env.XXXXXX")
trap 'rm -f -- "$temporary_config"' EXIT HUP INT TERM
chmod 0600 "$temporary_config"
{
  printf 'TELEGRAM_BOT_TOKEN=%s\n' "$bot_token"
  printf 'TELEGRAM_CHAT_ID=%s\n' "$chat_id"
} > "$temporary_config"
mv "$temporary_config" "$config_file"
trap - EXIT HUP INT TERM
printf '資格情報を %s に保存しました。\n' "$config_file"

link_skill "$codex_skill"
link_skill "$pi_skill"
printf 'Telegramスキルのセットアップが完了しました。\n'
