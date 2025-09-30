# Sui NFT Mint Sample (Hands-on)

このリポジトリは、Sui Testnet 上で最小構成の NFT ミント dApp を構築するハンズオン教材です。Move コントラクトと React + dApp Kit フロントエンドを組み合わせ、ウォレット接続から `move_call` 実行までを体験できます。

## ディレクトリ構成

- `contracts/` — Move パッケージ（`nft` モジュール）とテスト
- `app/` — React + Vite フロントエンド
- `docs/` — ハンズオン用ドキュメント
- `.devcontainer/` — GitHub Codespaces 向けの開発環境定義

## クイックスタート

1. Codespaces またはローカル環境でリポジトリを開く
2. `contracts/` で `sui move build`・`sui client publish` を実行し Package ID を取得
3. `app/.env.example` を `.env` にコピーし Package ID 等を入力
4. `pnpm install && pnpm dev -- --host` でフロントエンドを起動
5. ウォレットを接続して NFT をミント、Sui Vision で結果を確認

詳細な手順は `docs/HANDSON_GUIDE.md` を参照してください。

## ライセンス

MIT License
