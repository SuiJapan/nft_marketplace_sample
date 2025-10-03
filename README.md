# Sui Testnet NFT ミント手順

このリポジトリは、用意済みの Move コントラクト（Package ID `0xffb17d198be1636f5bc710a45581e78c52b0592db19b966c974fec737c30350d`）を使って、Sui Testnet 上で NFT をミントするハンズオン用フロントエンドを提供します。参加者はコントラクトをデプロイする必要はなく、Testnet でミントと確認を体験できます。

## 前提

- Chrome 等のブラウザ
- Sui Wallet など Testnet に切り替え可能なウォレット拡張（Testnet SUI を取得しておく）
- Node.js 18 以上 + pnpm（ローカルで起動する場合）
- または VS Code + Dev Container（Docker 環境、推奨）

## セットアップ方法

### Dev Container を使う場合（推奨）

1. リポジトリをクローンし、VS Code で開きます。
2. 「Dev Container で再度開く」を選択します。
   - Sui CLI、Node.js 22、pnpm が自動的にセットアップされます。
   - Sui Move の拡張機能も自動的にインストールされます。
3. コンテナ起動後、`app/.env` の設定を確認してください（Package ID は固定済み）。
4. 開発サーバを起動します。
   ```bash
   cd app
   pnpm dev -- --host
   ```

### ローカル環境で起動する場合

1. 依存関係をインストールします。
   ```bash
   cd app
   pnpm install
   ```
2. `app/.env` ファイルを確認します（Package ID は固定済み）。
   ```env
   VITE_SUI_NETWORK=testnet
   VITE_PACKAGE_ID=0xffb17d198be1636f5bc710a45581e78c52b0592db19b966c974fec737c30350d
   VITE_MODULE=nft
   VITE_FN_MINT=mint
   ```
   ※ `.env` ファイルはリポジトリに含まれていますが、必要に応じて値を変更できます。
3. 開発サーバを起動します。
   ```bash
   cd app
   pnpm dev -- --host
   ```

## ミント手順

1. 表示された URL をブラウザで開き、Sui Wallet を Testnet に切り替えた状態で接続します。
2. 名前・説明・画像 URL を入力し、「NFT をミント」を押してウォレットで署名します。
3. 画面下部に Tx Digest と Object ID が表示されます。その値を控えて次の確認手順に進みます。

## パッケージの確認方法

- [Sui Vision (Testnet)](https://testnet.suivision.xyz/package/0xffb17d198be1636f5bc710a45581e78c52b0592db19b966c974fec737c30350d)
  - `Code` タブで `nft::mint` と `init` を確認できます。
  - `Objects` タブに Display オブジェクトが発行者に転送されていることも確認できます。

## ミント結果（Tx / NFT）の確認方法

1. [Sui Vision](https://suivision.xyz/?network=testnet) を開きます。右上が Testnet になっていることを確認してください。
2. ミント画面で控えた ID を検索欄に貼り付けて確認します。
   - `Tx Digest`: トランザクション詳細が表示され、イベントやガス代を確認できます。
   - `Object ID`: ミントした NFT オブジェクトの所有者・フィールド (`name`, `description`, `image_url`) が表示されます。
3. 必要に応じてウォレットの `Objects` タブでも所有状態を確認してください。

## コントラクトについて

### Move コード
- Move コードは [contracts/sources/nft.move](contracts/sources/nft.move) にあります。
- ワークショップ向けに日本語コメントが充実しており、学習しやすい構成になっています。
- `WorkshopNFT` 構造体が NFT 本体で、`key` と `store` 能力を持ちます。
- `mint` 関数でミントし、`public_transfer` でウォレットに転送します。

### Display オブジェクト
- publish 時に `init` 関数が実行され、Display のテンプレート（name/description/image_url/link）が自動登録されます。
- Display オブジェクトは `public_transfer` で発行者に直接転送されます（以前は `public_share_object` で共有していました）。

### フロントエンド
- フロントエンドは `app/src` にあり、`@mysten/dapp-kit` でウォレット接続と `move_call` を行います。
- React + TypeScript + Vite で構成されています。

### 開発環境
- `.devcontainer/` に Dev Container の設定があり、VS Code で簡単に開発環境を構築できます。
- Sui CLI は起動時に自動的に最新版に更新されます。
- pnpm は corepack で自動的に有効化されます。

## まとめ

これで Testnet 上での NFT ミント体験が完結します。ウォレットが Testnet になっていることと、Tx Digest / Object ID を正しく控えることに注意してください。
