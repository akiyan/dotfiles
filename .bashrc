# .bashrc - 対話シェル用
# macOS、Ubuntu、Amazon Linux 2023 の bash で共通して使う。

case $- in
  *i*) ;;
  *) return ;;
esac

alias yolo='codex --dangerously-bypass-approvals-and-sandbox --dangerously-bypass-hook-trust'

# 履歴
HISTSIZE=100000
HISTFILESIZE=200000
HISTCONTROL=ignoreboth
# 履歴ファイルの「#<epoch>」行をタイムスタンプとして扱う。
HISTTIMEFORMAT='%F %T '
shopt -s histappend
shopt -s lithist
shopt -s checkwinsize

# setup.sh がホームディレクトリへ導入した補完と Git プロンプトを読み込む。
dotfiles_data_dir="${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles"
bash_completion_file="$dotfiles_data_dir/bash-completion/bash_completion"
if [ -r "$bash_completion_file" ]; then
  # macOS 標準の Bash 3.2 用 bash-completion 1.3 は、既定では
  # /etc/bash_completion を参照するため、ホーム配下の導入先を明示する。
  if [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
    BASH_COMPLETION="$bash_completion_file"
    BASH_COMPLETION_DIR="$dotfiles_data_dir/bash-completion/completions"
    BASH_COMPLETION_COMPAT_DIR="$BASH_COMPLETION_DIR"
  fi
  . "$bash_completion_file"
fi
[ -r "$dotfiles_data_dir/git-prompt.sh" ] &&
  . "$dotfiles_data_dir/git-prompt.sh"
unset bash_completion_file dotfiles_data_dir

# ys テーマ風プロンプト
# 例: # akiyan @ host in ~/dir on git:main * [05:23:51]
if type __git_ps1 >/dev/null 2>&1; then
  GIT_PS1_SHOWDIRTYSTATE=1
  GIT_PS1_SHOWUNTRACKEDFILES=1
  GIT_PS1_SHOWSTASHSTATE=1
  GIT_PS1_SHOWCOLORHINTS=1

  __ps1_pre='\[\e[31m\]# \[\e[36m\]\u \[\e[37m\]@ \[\e[32m\]\h \[\e[37m\]in \[\e[33m\]\w\[\e[0m\]'
  __ps1_post=' \[\e[34m\][\t]\[\e[0m\]\n\$ '
  PROMPT_COMMAND='__git_ps1 "$__ps1_pre" "$__ps1_post" " on git:%s"'
else
  PS1='\[\e[31m\]# \[\e[36m\]\u \[\e[37m\]@ \[\e[32m\]\h \[\e[37m\]in \[\e[33m\]\w\[\e[34m\] [\t]\[\e[0m\]\n\$ '
fi
