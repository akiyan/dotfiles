# .bash_profile - ログインシェル用
# macOS、Ubuntu、Amazon Linux 2023 の bash で共通して使う。

# setup.sh が導入するユーザー用コマンド
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

# 対話シェル用の設定は .bashrc にまとめる。
[ -r "$HOME/.bashrc" ] && . "$HOME/.bashrc"
