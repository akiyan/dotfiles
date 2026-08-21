#!/usr/bin/env bash
set -euo pipefail

readonly REPOSITORY_URL='https://github.com/akiyan/dotfiles.git'
dotfiles_dir="${DOTFILES_DIR:-$HOME/.dotfiles}"

die() {
  printf 'エラー: %s\n' "$*" >&2
  exit 1
}

command -v git >/dev/null 2>&1 || die 'git が必要です'

if [ -d "$dotfiles_dir/.git" ]; then
  origin_url=$(git -C "$dotfiles_dir" remote get-url origin 2>/dev/null || true)
  case "$origin_url" in
    "$REPOSITORY_URL"|git@github.com:akiyan/dotfiles.git) ;;
    *) die "$dotfiles_dir の origin は akiyan/dotfiles ではありません" ;;
  esac

  if [ -n "$(git -C "$dotfiles_dir" status --porcelain)" ]; then
    die "$dotfiles_dir に未コミットの変更があります"
  fi

  git -C "$dotfiles_dir" fetch origin main
  git -C "$dotfiles_dir" checkout main
  if git -C "$dotfiles_dir" merge-base --is-ancestor main origin/main; then
    git -C "$dotfiles_dir" merge --ff-only origin/main
  elif ! git -C "$dotfiles_dir" merge-base main origin/main >/dev/null 2>&1; then
    # リポジトリ側で履歴を1コミット化した場合は管理cloneを同期する。
    git -C "$dotfiles_dir" reset --hard origin/main
  else
    die "$dotfiles_dir のmainとorigin/mainが分岐しています"
  fi
elif [ -e "$dotfiles_dir" ] || [ -L "$dotfiles_dir" ]; then
  die "$dotfiles_dir は既に存在します"
else
  git clone --branch main --single-branch "$REPOSITORY_URL" "$dotfiles_dir"
fi

bash "$dotfiles_dir/setup.sh"
