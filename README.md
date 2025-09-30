# Sui Testnet NFT ミント手順

このリポジトリは、用意済みの Move コントラクト（Package ID `0xad1b749cc2932edc42351ba086b371bd75b9a2b2347abf71c30469bf66f188af`）を使って、Sui Testnet 上で NFT をミントするハンズオン用フロントエンドを提供します。参加者はコントラクトをデプロイする必要はなく、Testnet でミントと確認を体験できます。

## 前提

- Chrome 等のブラウザ
- Sui Wallet など Testnet に切り替え可能なウォレット拡張（Testnet SUI を取得しておく）
- Node.js 18 以上 + pnpm（ローカルで起動する場合）

## セットアップとミント手順

1. 依存関係をインストールします。
   ```bash
   cd app
   pnpm install
   ```
2. `.env` を作成し、以下の内容を設定します（Package ID は固定済み）。
   ```env
   VITE_SUI_NETWORK=testnet
   VITE_PACKAGE_ID=0xad1b749cc2932edc42351ba086b371bd75b9a2b2347abf71c30469bf66f188af
   VITE_MODULE=nft
   VITE_FN_MINT=mint
   ```
3. 開発サーバを起動します。
   ```bash
   pnpm dev -- --host
   ```
   表示された URL をブラウザで開き、Sui Wallet を Testnet に切り替えた状態で接続します。
4. 名前・説明・画像 URL を入力し、「NFT をミント」を押してウォレットで署名します。
5. 画面下部に Tx Digest と Object ID が表示されます。その値を控えて次の確認手順に進みます。

## パッケージの確認方法

- [Sui Vision (Testnet)](https://suivision.xyz/package/0xad1b749cc2932edc42351ba086b371bd75b9a2b2347abf71c30469bf66f188af?network=testnet)
  - `Code` タブで `nft::mint` と `init` を確認できます。
  - `Objects` タブに Display オブジェクトが共有されていることも表示されます。

## ミント結果（Tx / NFT）の確認方法

1. [Sui Vision](https://suivision.xyz/?network=testnet) を開きます。右上が Testnet になっていることを確認してください。
2. ミント画面で控えた ID を検索欄に貼り付けて確認します。
   - `Tx Digest`: トランザクション詳細が表示され、イベントやガス代を確認できます。
   - `Object ID`: ミントした NFT オブジェクトの所有者・フィールド (`name`, `description`, `image_url`) が表示されます。
3. 必要に応じてウォレットの `Objects` タブでも所有状態を確認してください。

## コントラクトについて

- Move コードは `contracts/sources/nft.move` にあります。
- publish 時に `init` が走り、Display のテンプレート（name/description/image/link）が自動登録されます。
- フロントエンドは `app/src` にあり、`@mysten/dapp-kit` でウォレット接続と `move_call` を行います。


これで Testnet 上での NFT ミント体験が完結します。ウォレットが Testnet になっていることと、Tx Digest / Object ID を正しく控えることに注意してください。
