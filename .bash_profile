# .bash_profile - ログインシェル用
# macOS、Ubuntu、Amazon Linux 2023 の bash で共通して使う。

# Homebrewの環境をmacOSのログインシェルへ反映する。
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# setup.sh が導入するユーザー用コマンド
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

# 対話シェル用の設定は .bashrc にまとめる。
[ -r "$HOME/.bashrc" ] && . "$HOME/.bashrc"
