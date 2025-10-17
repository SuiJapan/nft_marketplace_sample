# Proposal: NFT Contract Implementation

## Why

現在、プロジェクトには空のコントラクトファイルしか存在せず、NFT マーケットプレイスの中核機能である NFT の mint、Kiosk への出品、TransferPolicy の初期化が実装されていません。この変更により、Sui ブロックチェーン上で動作する最小構成の NFT マーケットプレイスコントラクトを実装し、フロントエンドとの連携を可能にします。

## What Changes

- **新規機能**: WorkshopNft 構造体の定義（Display 標準対応）
- **新規機能**: NFT mint 機能（`mint_nft`, `mint` entry）
- **新規機能**: TransferPolicy 初期化機能（`init_transfer_policy` entry）
- **新規機能**: Kiosk 出品機能（`place_and_list_core`, `mint_and_list` entry）
- **アーキテクチャ**: Move 2024 可視性ポリシーに準拠した設計
  - 実処理: `public(package)` 関数
  - 外部インターフェース: `entry` 関数（薄い実装）

## Impact

### 影響を受ける仕様
- **新規作成**: `nft-core` capability
  - NFT の定義と mint
  - TransferPolicy の初期化
  - Kiosk との連携

### 影響を受けるコード
- `contract/sources/contract.move` → `contract/sources/workshop_nft.move` へリネーム・実装
- `contract/Move.toml`: 依存関係の追加（Sui Framework）
- フロントエンド: 今後の変更で NFT イベントを購読し、UI に反映

### 技術的影響
- **Sui Framework 依存**: `0x2::kiosk`, `0x2::transfer_policy`, `0x2::display`, `0x2::package`
- **デプロイ後の初期化**: `init_transfer_policy` を管理者が 1 回実行する必要
- **ネットワーク対応**: testnet/devnet/mainnet で動作
