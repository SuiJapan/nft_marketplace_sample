# Sui NFT ミントハンズオン手順書

本資料は `nft-mint-sample` リポジトリを使って、Sui Testnet 上で NFT をミントする最小 dApp を体験するための手順です。Codespaces を前提にしていますが、ローカルでも同様に実施できます。

## 1. Codespaces / 開発環境の準備

1. GitHub でリポジトリを Fork する（必要に応じて）。
2. 「Code」ボタン → 「Codespaces」タブ → 「Create codespace on dev」 を選択。
3. 初回起動時に `.devcontainer/setup.sh` が走り、Sui CLI / pnpm / Rust が自動インストールされます。
4. ターミナルで以下を確認：

   ```bash
   sui --version
   pnpm --version
   ```

## 2. Move パッケージのビルドと Publish

1. `contracts/` ディレクトリに移動：

   ```bash
   cd contracts
   sui move build
   ```

2. Testnet の RPC を設定（初回のみ）：

   ```bash
   sui client envs
   sui client new-env --alias testnet --rpc https://fullnode.testnet.sui.io:443
   sui client switch --env testnet
   ```

3. アドレスとガス残高を確認：

   ```bash
   sui client addresses
   sui client gas
   ```

4. Publish して Package ID を取得：

   ```bash
   sui client publish --path . --json
   ```

   出力 JSON の `packageId` を控え、フロントエンドの `.env` に設定します。

5. 今回のバージョンでは publish 時に Display が自動作成されるため、追加コマンドは不要です。Sui Vision / Explorer で画像付きカード表示が利用できます。

## 3. フロントエンドのセットアップ

1. Codespaces で `app/` ディレクトリに移動：

   ```bash
   cd /workspaces/nft-mint-sample/app
   pnpm install
   cp .env.example .env
   ```

2. `.env` を編集して以下を指定：

   ```env
   VITE_SUI_NETWORK=testnet
   VITE_PACKAGE_ID=0x...
   VITE_MODULE=nft
   VITE_FN_MINT=mint
   ```

3. 開発サーバーを起動：

   ```bash
   pnpm dev -- --host
   ```

4. Codespaces のポート 5173 を公開し、ブラウザで `https://<name>-5173.app.github.dev` にアクセスします。

## 4. ミントの手順

1. ブラウザでウォレット拡張（Sui Wallet 等）を Testnet に切り替えます。
2. 画面右上の「ウォレットを接続」からウォレットを接続。
3. 「テンプレート画像を使う」または「自分で URL を指定する」を選択。
4. 名前・説明を入力して「NFT をミント」。
5. ウォレットでトランザクションに署名。
6. 結果パネルでトランザクションダイジェストとオブジェクト ID を確認し、Sui Vision へのリンクから状態をチェック。

## 5. よくあるエラーと対策

| 症状 | 対応 |
| --- | --- |
| `Module not found` | `.env` に正しい Package ID / モジュール名を設定しているか確認。publish 済みか再確認。 |
| `Insufficient gas` | Testnet Faucet で SUI を補充し、再度 publish / mint を実行。 |
| トランザクションが Pending のまま | 数分待ってからエクスプローラで確認。Testnet の混雑が原因。
| ウォレット接続不可 | 拡張機能が `*.github.dev` ドメインを許可しているか、Testnet に切り替わっているかを確認。 |

## 6. 片付け

* `pnpm dev` を終了して Codespaces を停止。
* 必要に応じて `sui client switch --env <元のネットワーク>` で環境を戻す。
* keystore が必要な場合は `~/.sui/sui_config` をバックアップ。

---

## 付録：画像テンプレートの意図

テンプレートには汎用的で視認性の高い 3 種類の画像を用意しています（Aurora / Crystal / Echo）。

* 初学者でも成果物が視覚的にわかりやすいようグラデーション系のデザインを採用。
* カスタム画像 URL を入力できるフォームも用意し、自作作品でのミントに拡張可能。
* 画像ホスティングを学びたい参加者には IPFS や Walrus を追加課題として紹介できます。
