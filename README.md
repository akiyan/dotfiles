# dotfiles

macOS、Ubuntu、Amazon Linux 2023 で共通利用する Bash 環境と開発用 CLI をセットアップする。

## インストール

`curl`、`git`、`tar` が必要。macOS で ripgrep を導入する場合は Homebrew も必要になる。

```bash
curl -fsSL https://raw.githubusercontent.com/akiyan/dotfiles/main/install.sh | bash
```

完了後、ログインシェルを起動し直す。

```bash
exec bash -l
```

## インストールされるもの

### Bash設定

- リポジトリを `~/.dotfiles` にclone
- `.bash_profile` と `.bashrc` をホームディレクトリへシンボリックリンク
- Bashのバージョンに対応した `bash-completion`
  - Bash 4.2以降: bash-completion 2系
  - macOS標準の Bash 3.2: bash-completion 1系
- Git公式の `git-prompt.sh`

既存の `.bash_profile` と `.bashrc` は、それぞれ `.before-dotfiles` という接尾辞を付けて退避する。

### CLI

| コマンド | 用途 | インストール方法 |
| --- | --- | --- |
| `rg` | 高速なファイル・テキスト検索 | macOSはHomebrew、Ubuntuはapt、Amazon Linux 2023はdnf/SPAL（AL2023.9以降） |
| `gh` | GitHub CLI | GitHub Releasesから `~/.local/bin` へ導入 |
| `aws` | AWS CLI v2 | AWS公式インストーラー |
| `herdr` | Herdr CLI | Herdr公式インストーラー |
| `claude` | Claude Code | Anthropic公式インストーラー |
| `codex` | Codex CLI | OpenAI公式インストーラー |

`rg` 以外のCLIがすでにシステムや別のパッケージマネージャーで管理されている場合、そのCLIのインストールはスキップする。

## できるようになること

- Gitブランチ名と作業ツリーの状態を含むプロンプト表示
- Bashのコマンド補完
- シェル内10万件・履歴ファイル20万件のコマンド履歴と日時表示
- 複数行コマンドを保った履歴保存
- `~/.local/bin` に導入したCLIの実行
- `yolo` エイリアスによるCodex CLIの承認・サンドボックス省略実行

`yolo` は次の危険なオプションを有効にするため、信頼できるディレクトリでのみ使用する。

```bash
alias yolo='codex --dangerously-bypass-approvals-and-sandbox --dangerously-bypass-hook-trust'
```

## 更新と再実行

インストールコマンドは何度でも実行できる。再実行すると `~/.dotfiles` をmainブランチの最新版へfast-forwardし、管理対象のCLIを最新版へ更新して設定を再適用する。

`~/.dotfiles` に未コミットの変更がある場合は、変更を保護するため更新せず停止する。
