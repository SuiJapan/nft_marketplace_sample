# NFT Marketplace Sample

Sui ブロックチェーン上で動作する NFT マーケットプレイスのサンプル実装です。

## 概要

このプロジェクトは、Sui の標準 Kiosk インフラを活用した分散型 NFT マーケットプレイスです。以下の機能を提供します：

- **NFT の mint**: WorkshopNft の発行
- **出品機能**: mint と同時に Kiosk へ出品（`mint_and_list`）
- **TransferPolicy 初期化**: Kiosk での売買を可能にする

## プロジェクト構造

```
.
├── contract/               # Sui Move コントラクト
│   ├── sources/
│   │   └── workshop_nft.move
│   ├── tests/
│   │   └── workshop_nft_tests.move
│   └── Move.toml
├── frontend/               # Next.js フロントエンド（予定）
└── openspec/              # OpenSpec 仕様
```

## 技術スタック

### Backend (Sui Move)
- **Sui Move** (Move 2024 仕様準拠)
- **Kiosk 標準**: place / list / purchase API による NFT 取引
- **TransferPolicy 標準**: 型 `T` のトレード可否制御
- **Display 標準**: NFT メタデータのフロント表示サポート

## セットアップ

### 前提条件

- [Sui CLI](https://docs.sui.io/build/install) のインストール
- Sui wallet の設定

### インストール

1. リポジトリのクローン
```bash
git clone <repository-url>
cd nft_marketplace_sample
```

2. 依存関係の取得
```bash
cd contract
sui move build
```

## テスト

### 単体テスト

```bash
cd contract
sui move test
```

## デプロイ

### 1. コントラクトのデプロイ

```bash
cd contract
sui client publish --gas-budget 100000000
```

デプロイ結果から以下の情報を記録してください：
- **Package ID**: デプロイされたパッケージの ID
- **Publisher Object ID**: Publisher オブジェクトの ID

### 2. TransferPolicy の初期化

デプロイ後、必ず以下のコマンドを実行して TransferPolicy を初期化してください。
これにより、WorkshopNft が Kiosk で売買可能になります。

```bash
sui client call \
  --package <PACKAGE_ID> \
  --module workshop_nft \
  --function init_transfer_policy \
  --args <PUBLISHER_OBJECT_ID> \
  --gas-budget 10000000
```

実行結果から以下を記録してください：
- **TransferPolicy Object ID**: 共有された TransferPolicy の ID
- **TransferPolicyCap Object ID**: 今後のポリシー更新に使用

### 3. NFT の mint

```bash
sui client call \
  --package <PACKAGE_ID> \
  --module workshop_nft \
  --function mint \
  --args "My NFT" "A cool NFT" "https://example.com/nft.png" \
  --gas-budget 10000000
```

### 4. NFT の mint と出品（一括）

まず、Kiosk を作成します：

```bash
sui client call \
  --package 0x2 \
  --module kiosk \
  --function default \
  --gas-budget 10000000
```

実行結果から以下を記録してください：
- **Kiosk Object ID**: 作成された Kiosk の ID
- **KioskOwnerCap Object ID**: Kiosk の所有権証明

次に、NFT を mint して出品します：

```bash
sui client call \
  --package <PACKAGE_ID> \
  --module workshop_nft \
  --function mint_and_list \
  --args <KIOSK_ID> <KIOSK_OWNER_CAP_ID> "Listed NFT" "An NFT for sale" "https://example.com/sale.png" 1000000000 \
  --gas-budget 10000000
```

価格は MIST 単位で指定します（1 SUI = 1,000,000,000 MIST）。

## Move 2024 可視性ポリシー

このプロジェクトは Move 2024 の可視性ポリシーに準拠しています：

- **実処理**: `public(package)` 関数で実装
- **外部インターフェース**: `entry` 関数（薄い実装）
- **PTB 呼出対象**: `entry` / `public` のみ

### 主要関数

#### NFT Mint
- `entry fun mint()`: NFT を mint して呼び出し元に転送
- `public(package) fun mint_nft()`: NFT 作成の実処理

#### TransferPolicy
- `entry fun init_transfer_policy()`: TransferPolicy の初期化（デプロイ後 1 回実行）

#### Kiosk 連携
- `entry fun mint_and_list()`: mint と Kiosk 出品を一括実行
- `public(package) fun place_and_list_core()`: Kiosk 出品の実処理

## トラブルシューティング

### TransferPolicy が初期化されていない

エラー: `TransferPolicy<WorkshopNft>` が見つかりません

**解決策**: デプロイ後に `init_transfer_policy` を実行してください。

### 価格の単位が間違っている

エラー: 想定外の価格で出品されました

**解決策**: 価格は MIST 単位で指定します。1 SUI = 1,000,000,000 MIST

### ビルドエラー

エラー: 依存関係の解決に失敗しました

**解決策**:
```bash
rm -rf ~/.move
sui move build
```

## ライセンス

MIT

## 参考資料

- [Kiosk 公式ドキュメント](https://docs.sui.io/standards/kiosk)
- [TransferPolicy 公式ドキュメント](https://docs.sui.io/standards/kiosk/transfer-policy)
- [Sui Move 2024 ガイドライン](https://docs.sui.io/concepts/sui-move-concepts/conventions)
