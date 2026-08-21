#!/usr/bin/env bash
set -euo pipefail

readonly BASH_COMPLETION_LEGACY_REF='1.3'
readonly BASH_COMPLETION_LEGACY_COMMIT='7c81ef895455d0f7543c65789ff62808e7465578'
readonly BASH_COMPLETION_CURRENT_REF='2.18.0'
readonly BASH_COMPLETION_CURRENT_COMMIT='b80d38cce5645fb98acd4eba857843fdf66be570'
readonly GIT_PROMPT_COMMIT='e9019fcafe0040228b8631c30f97ae1adb61bcdc'

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
data_dir="${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles"
bash_completion_dir="$data_dir/bash-completion"
local_bin_dir="$HOME/.local/bin"
initial_path=$PATH
temporary_dir=''

cleanup() {
  case "$temporary_dir" in
    "$data_dir"/.setup.*) rm -rf -- "$temporary_dir" ;;
  esac
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

die() {
  printf 'エラー: %s\n' "$*" >&2
  exit 1
}

command -v curl >/dev/null 2>&1 || die 'curl が必要です'
command -v git >/dev/null 2>&1 || die 'git が必要です'
command -v tar >/dev/null 2>&1 || die 'tar が必要です'

mkdir -p "$data_dir" "$local_bin_dir"
temporary_dir=$(mktemp -d "$data_dir/.setup.XXXXXX")
export PATH="$local_bin_dir:$PATH"

skip_if_externally_managed() {
  command_name=$1
  existing_path=$(PATH="$initial_path" command -v "$command_name" 2>/dev/null || true)

  if [ -z "$existing_path" ]; then
    return 1
  fi
  if [ -x "$local_bin_dir/$command_name" ]; then
    return 1
  fi
  if [ "$existing_path" = "$local_bin_dir/$command_name" ]; then
    return 1
  fi

  printf '%s は %s にあるためインストールをスキップします\n' \
    "$command_name" "$existing_path"
  return 0
}

link_file() {
  source_path=$1
  target_path=$2

  if [ -L "$target_path" ] && [ "$source_path" -ef "$target_path" ]; then
    return
  fi

  if [ -e "$target_path" ] || [ -L "$target_path" ]; then
    backup_path="${target_path}.before-dotfiles"
    [ ! -e "$backup_path" ] && [ ! -L "$backup_path" ] ||
      die "$target_path と $backup_path の両方が存在するため置換できません"
    mv "$target_path" "$backup_path"
    printf '既存ファイルを %s へ退避しました\n' "$backup_path"
  fi

  ln -s "$source_path" "$target_path"
}

link_file "$repo_dir/.bash_profile" "$HOME/.bash_profile"
link_file "$repo_dir/.bashrc" "$HOME/.bashrc"

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  elif command -v openssl >/dev/null 2>&1; then
    openssl dgst -sha256 "$1" | awk '{print $NF}'
  else
    die 'SHA-256 の検証に sha256sum、shasum、または openssl が必要です'
  fi
}

download() {
  curl -fsSL --retry 3 --connect-timeout 10 --max-time 300 "$1" -o "$2"
}

github_latest_tag() {
  release_json=$(curl -fsSL --retry 3 --connect-timeout 10 --max-time 30 \
    -H 'Accept: application/vnd.github+json' \
    "https://api.github.com/repos/$1/releases/latest")
  release_tag=$(printf '%s\n' "$release_json" |
    sed -n 's/^[[:space:]]*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' |
    sed -n '1p')
  [ -n "$release_tag" ] || die "$1 の最新バージョンを取得できませんでした"
  printf '%s\n' "$release_tag"
}

verify_checksum() {
  actual_checksum=$(sha256_file "$1")
  [ "$actual_checksum" = "$2" ] || die "$(basename "$1") のチェックサム検証に失敗しました"
}

install_binary() {
  source_binary=$1
  binary_name=$2
  staged_binary="$temporary_dir/$binary_name.ready"
  cp "$source_binary" "$staged_binary"
  chmod 0755 "$staged_binary"
  mv "$staged_binary" "$local_bin_dir/$binary_name"
}

run_as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    command -v sudo >/dev/null 2>&1 || die 'この処理には sudo が必要です'
    sudo "$@"
  fi
}

case "$(uname -s):$(uname -m)" in
  Darwin:x86_64)
    gh_target='macOS_amd64'
    gh_archive_extension='zip'
    ;;
  Darwin:arm64|Darwin:aarch64)
    gh_target='macOS_arm64'
    gh_archive_extension='zip'
    ;;
  Linux:x86_64|Linux:amd64)
    gh_target='linux_amd64'
    gh_archive_extension='tar.gz'
    ;;
  Linux:arm64|Linux:aarch64)
    gh_target='linux_arm64'
    gh_archive_extension='tar.gz'
    ;;
  *) die "未対応の環境です: $(uname -s) $(uname -m)" ;;
esac

install_ripgrep() {
  printf 'システムのパッケージマネージャーで ripgrep の最新版を確認しています...\n'

  case "$(uname -s)" in
    Darwin)
      command -v brew >/dev/null 2>&1 ||
        die 'macOS で ripgrep を導入するには Homebrew が必要です'
      brew update
      if brew list --formula ripgrep >/dev/null 2>&1; then
        if brew outdated --quiet ripgrep | grep -q .; then
          brew upgrade ripgrep
        else
          printf 'ripgrep は最新です\n'
        fi
      else
        brew install ripgrep
      fi
      ;;
    Linux)
      [ -r /etc/os-release ] || die '/etc/os-release を読み込めません'
      # shellcheck disable=SC1091
      . /etc/os-release
      case "${ID:-}" in
        ubuntu)
          run_as_root apt-get update
          run_as_root apt-get install -y ripgrep
          ;;
        amzn)
          [ "${VERSION_ID:-}" = '2023' ] ||
            die "未対応の Amazon Linux です: ${VERSION_ID:-不明}"
          if ! dnf --quiet list ripgrep >/dev/null 2>&1; then
            printf 'ripgrep のために Amazon Linux 公式の SPAL を有効化します...\n'
            if ! run_as_root dnf install -y spal-release; then
              die 'SPAL を利用するには Amazon Linux 2023.9 以降が必要です'
            fi
          fi
          run_as_root dnf install -y ripgrep
          ;;
        *) die "未対応の Linux ディストリビューションです: ${ID:-不明}" ;;
      esac
      ;;
  esac

  # 以前の setup.sh が導入したものは、システム版を隠すため削除する。
  if [ -f "$local_bin_dir/rg" ]; then
    rm -- "$local_bin_dir/rg"
    printf '旧 ~/.local/bin/rg を削除しました\n'
  fi
}

install_gh() {
  if skip_if_externally_managed gh; then
    return
  fi

  gh_tag=$(github_latest_tag cli/cli)
  gh_version=${gh_tag#v}
  installed_version=$({ "$local_bin_dir/gh" --version 2>/dev/null || true; } |
    sed -n '1s/^gh version \([^ ]*\).*/\1/p')
  if [ "$installed_version" = "$gh_version" ]; then
    printf 'gh %s は最新です\n' "$gh_version"
    return
  fi

  asset="gh_${gh_version}_${gh_target}.${gh_archive_extension}"
  base_url="https://github.com/cli/cli/releases/download/$gh_tag"
  archive="$temporary_dir/$asset"
  checksums="$temporary_dir/gh-checksums.txt"
  extract_dir="$temporary_dir/gh"
  printf 'gh %s をインストールしています...\n' "$gh_version"
  download "$base_url/$asset" "$archive"
  download "$base_url/gh_${gh_version}_checksums.txt" "$checksums"
  expected_checksum=$(awk -v asset="$asset" '$2 == asset {print $1; exit}' "$checksums")
  [ -n "$expected_checksum" ] || die "$asset のチェックサムが見つかりません"
  verify_checksum "$archive" "$expected_checksum"
  mkdir "$extract_dir"
  tar -xf "$archive" -C "$extract_dir"
  binary=$(find "$extract_dir" -type f -path '*/bin/gh' -print | sed -n '1p')
  [ -n "$binary" ] || die 'gh の実行ファイルが見つかりません'
  install_binary "$binary" gh
  printf 'gh %s をインストールしました\n' "$gh_version"
}

run_official_installers() {
  aws_installer="$temporary_dir/aws-cli-install.sh"
  herdr_installer="$temporary_dir/herdr-install.sh"
  claude_installer="$temporary_dir/claude-install.sh"
  codex_installer="$temporary_dir/codex-install.sh"

  if ! skip_if_externally_managed aws; then
    printf 'AWS CLI v2 の最新版を確認しています...\n'
    download https://awscli.amazonaws.com/v2/install.sh "$aws_installer"
    XDG_BIN_HOME="$local_bin_dir" bash "$aws_installer"
  fi

  if ! skip_if_externally_managed herdr; then
    printf 'Herdr の最新版を確認しています...\n'
    download https://herdr.dev/install.sh "$herdr_installer"
    HERDR_INSTALL_DIR="$local_bin_dir" sh "$herdr_installer"
  fi

  if ! skip_if_externally_managed claude; then
    printf 'Claude Code の最新版を確認しています...\n'
    download https://claude.ai/install.sh "$claude_installer"
    bash "$claude_installer" latest
  fi

  if ! skip_if_externally_managed codex; then
    printf 'Codex CLI の最新版を確認しています...\n'
    download https://chatgpt.com/codex/install.sh "$codex_installer"
    CODEX_NON_INTERACTIVE=1 CODEX_INSTALL_DIR="$local_bin_dir" \
      sh "$codex_installer"
  fi
}

install_ripgrep
install_gh
run_official_installers

if ((BASH_VERSINFO[0] > 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 2))); then
  bash_completion_ref=$BASH_COMPLETION_CURRENT_REF
  bash_completion_commit=$BASH_COMPLETION_CURRENT_COMMIT
else
  bash_completion_ref=$BASH_COMPLETION_LEGACY_REF
  bash_completion_commit=$BASH_COMPLETION_LEGACY_COMMIT
fi

installed_commit=''
if [ -d "$bash_completion_dir/.git" ]; then
  installed_commit=$(git -C "$bash_completion_dir" rev-parse HEAD 2>/dev/null || true)
elif [ -e "$bash_completion_dir" ] || [ -L "$bash_completion_dir" ]; then
  die "$bash_completion_dir は dotfiles が管理する Git リポジトリではありません"
fi

if [ "$installed_commit" != "$bash_completion_commit" ]; then
  mkdir "$temporary_dir/bash-completion"
  git -C "$temporary_dir/bash-completion" init --quiet
  git -C "$temporary_dir/bash-completion" remote add origin \
    https://github.com/scop/bash-completion.git
  git -C "$temporary_dir/bash-completion" fetch --quiet --depth 1 origin \
    "refs/tags/$bash_completion_ref"
  git -C "$temporary_dir/bash-completion" config core.sparseCheckout true
  printf '%s\n' \
    '/bash_completion' \
    '/completions/' \
    '/completions-core/' \
    '/completions-fallback/' \
    '/helpers/' \
    '/startup/' \
    > "$temporary_dir/bash-completion/.git/info/sparse-checkout"
  git -C "$temporary_dir/bash-completion" checkout --quiet "$bash_completion_commit"

  cloned_commit=$(git -C "$temporary_dir/bash-completion" rev-parse HEAD)
  [ "$cloned_commit" = "$bash_completion_commit" ] ||
    die "bash-completion $bash_completion_ref の検証に失敗しました"

  if [ -d "$bash_completion_dir/.git" ]; then
    mv "$bash_completion_dir" "$temporary_dir/previous-bash-completion"
    if ! mv "$temporary_dir/bash-completion" "$bash_completion_dir"; then
      mv "$temporary_dir/previous-bash-completion" "$bash_completion_dir"
      die 'bash-completion を更新できませんでした'
    fi
  else
    mv "$temporary_dir/bash-completion" "$bash_completion_dir"
  fi
fi

git_prompt_url="https://raw.githubusercontent.com/git/git/$GIT_PROMPT_COMMIT/contrib/completion/git-prompt.sh"
git_prompt_temp="$temporary_dir/git-prompt.sh"
curl -fsSL "$git_prompt_url" -o "$git_prompt_temp"
chmod 0644 "$git_prompt_temp"
if [ ! -f "$data_dir/git-prompt.sh" ] || ! cmp -s "$git_prompt_temp" "$data_dir/git-prompt.sh"; then
  mv "$git_prompt_temp" "$data_dir/git-prompt.sh"
else
  :
fi

printf 'dotfiles のセットアップが完了しました\n'
