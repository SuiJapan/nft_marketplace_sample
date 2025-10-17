# Design: NFT Contract Implementation

## Context

本プロジェクトは Sui ブロックチェーン上で動作する NFT マーケットプレイスです。現在、空のコントラクトファイルのみが存在し、NFT の mint、Kiosk への出品、TransferPolicy の初期化といった中核機能が未実装です。

### 背景
- **Sui Move 2024**: 新しい可視性ポリシーを採用（`private`, `public(package)`, `public` の明確な使い分け）
- **Kiosk 標準**: Sui の標準 NFT マーケットプレイス基盤（`place`, `list`, `purchase` API）
- **TransferPolicy**: 型ごとのトレード可否を制御する共有オブジェクト

### 制約
- Move 2024 edition を使用（`contract/Move.toml` で指定済み）
- testnet/devnet/mainnet のマルチネットワーク対応が必要
- フロントエンドは Next.js + TypeScript で実装予定（イベント駆動設計）

### ステークホルダー
- **開発者**: ワークショップ参加者、学習者
- **エンドユーザー**: NFT の mint、出品、購入を行うユーザー
- **管理者**: TransferPolicy の初期化を行う運営者

---

## Goals / Non-Goals

### Goals
- **最小構成の NFT mint**: WorkshopNft の定義と mint 機能
- **Kiosk 連携**: NFT を Kiosk に配置・出品する機能
- **TransferPolicy 初期化**: デプロイ後に 1 回実行し、WorkshopNft の売買を可能にする
- **Move 2024 準拠**: 可視性ポリシーに従った設計（entry は薄く、実処理は public(package)）
- **Display 標準対応**: フロントエンドでのメタデータ表示を容易にする

### Non-Goals
- **手数料システム**: 初期実装では手数料を徴収しない（将来的に kiosk_extension で実装可能）
- **オークション機能**: 固定価格での出品のみをサポート
- **NFT バーン**: NFT の削除機能は含まない
- **アクセス制御**: 誰でも mint 可能（デモ・学習用途のため）

---

## Decisions

### Decision 1: Move 2024 可視性ポリシーの採用

**選択**: 実処理を `public(package)` で実装し、`entry` 関数は薄くする

**理由**:
- Move 2024 の公式ガイドラインに準拠
- テスタビリティの向上（`public(package)` 関数は単体テスト可能）
- 将来的な拡張性（他のモジュールから実処理を再利用可能）

**代替案**:
- すべてを `public` にする → セキュリティリスク、意図しない呼び出しの可能性
- すべてを `entry` にする → テストが困難、再利用性が低い

---

### Decision 2: TransferPolicy の初期化方法

**選択**: `transfer_policy::default<WorkshopNft>` を使用

**理由**:
- 最もシンプルな実装（ルールなしの基本ポリシー）
- ワークショップ・学習用途に適している
- 将来的にカスタムルールを追加可能

**代替案**:
- `transfer_policy::new<WorkshopNft>` + カスタムルール → 初期実装では複雑すぎる
- TransferPolicy を使わない → Kiosk で売買できない

---

### Decision 3: mint_and_list の提供

**選択**: mint と Kiosk 出品を一括実行する `mint_and_list` entry 関数を提供

**理由**:
- ワークショップでの利便性（1 つの PTB で完結）
- ガス効率の向上（トランザクション数の削減）
- ユーザー体験の向上

**代替案**:
- mint のみを提供し、出品は別途実行 → 手順が増え、初心者に不親切
- フロントエンドで PTB を組み立てる → 複雑度が増す

---

### Decision 4: Display 標準の使用

**選択**: WorkshopNft に Display 標準を適用

**理由**:
- フロントエンドでの `showDisplay: true` による簡単なメタデータ取得
- Sui エコシステムの標準に準拠
- マーケットプレイスでの互換性

**代替案**:
- カスタムメタデータ構造 → 標準からの逸脱、互換性の低下

---

### Decision 5: エラーハンドリング戦略

**選択**: 定数でエラーコードを定義し、`assert!` でチェック

**理由**:
- Move のベストプラクティス
- デバッグが容易（エラーコードから原因を特定）
- トランザクション失敗時の明確なフィードバック

**代替案**:
- エラーメッセージなしでアボート → デバッグが困難
- Result 型を使用 → Move にはネイティブサポートがない

---

## Architecture

### Module Structure

```
contract/
├── Move.toml
├── sources/
│   └── workshop_nft.move    # メインモジュール
└── tests/
    └── workshop_nft_tests.move
```

### Function Visibility Hierarchy

```
entry fun mint()
  └─> public(package) fun mint_nft()

entry fun init_transfer_policy()
  └─> sui::transfer_policy::default<WorkshopNft>()

entry fun mint_and_list()
  ├─> public(package) fun mint_nft()
  └─> public(package) fun place_and_list_core()
       └─> kiosk::place_and_list()
```

### Data Flow

```
1. 初期化フロー:
   Deploy → init() → Display<WorkshopNft> 作成
   → init_transfer_policy() → TransferPolicy<WorkshopNft> 共有

2. mint フロー:
   User → mint() → mint_nft() → WorkshopNft 作成 → transfer

3. mint_and_list フロー:
   User → mint_and_list()
   ├─> mint_nft() → WorkshopNft 作成
   └─> place_and_list_core() → Kiosk 出品
       → ItemListed イベント発行
```

---

## Dependencies

### External Dependencies
- **Sui Framework**: 0x2 (kiosk, transfer_policy, display, package, transfer)
- **Sui Standard Library**: 0x1 (string, option)

### Move.toml Configuration
```toml
[dependencies]
Sui = { git = "https://github.com/MystenLabs/sui.git", subdir = "crates/sui-framework/packages/sui-framework", rev = "framework/mainnet" }

[addresses]
contract = "0x0"  # デプロイ時に実際のアドレスに置き換え
```

---

## Risks / Trade-offs

### Risk 1: TransferPolicy の初期化忘れ
**影響**: WorkshopNft が Kiosk で売買できない

**軽減策**:
- デプロイ手順書に明記
- フロントエンドで TransferPolicy の存在をチェック
- エラーメッセージで初期化を促す

---

### Risk 2: 価格単位の混乱（MIST vs SUI）
**影響**: 誤った価格での出品（例: 1 SUI のつもりが 1 MIST）

**軽減策**:
- コード内のコメントで明記
- フロントエンドで MIST_PER_SUI 定数を使用
- UI で SUI 単位を表示し、バックエンドで MIST に変換

---

### Risk 3: 空文字列や無効な入力
**影響**: 無効な NFT の作成、Kiosk の汚染

**軽減策**:
- エラーコードを定義（EEmptyString, EInvalidPrice）
- `assert!` で入力検証
- フロントエンドでもバリデーション

---

### Trade-off 1: シンプルさ vs 拡張性
**選択**: シンプルさを優先（デフォルト TransferPolicy、手数料なし）

**理由**: 学習用途に適している、将来的に拡張可能

**影響**: 本番環境では手数料システムが必要 → kiosk_extension で対応

---

### Trade-off 2: ガス効率 vs コードの明瞭性
**選択**: コードの明瞭性を優先（可視性の分離、関数の分割）

**理由**: 学習者にとって理解しやすい、メンテナンス性が高い

**影響**: 若干のガスコスト増加 → ワークショップでは許容範囲

---

## Migration Plan

### Initial Deployment
1. **ビルド**: `sui move build`
2. **デプロイ**: `sui client publish --gas-budget 100000000`
3. **パッケージ ID 取得**: デプロイ結果から `packageId` を記録
4. **TransferPolicy 初期化**:
   ```bash
   sui client call \
     --package <PACKAGE_ID> \
     --module workshop_nft \
     --function init_transfer_policy \
     --args <PUBLISHER_OBJECT_ID> \
     --gas-budget 10000000
   ```
5. **TransferPolicy ID 取得**: 共有オブジェクトとして作成された TransferPolicy の ID を記録
6. **フロントエンドに設定**: パッケージ ID と TransferPolicy ID を環境変数に設定

### Rollback Strategy
- コントラクトのバグが発見された場合:
  1. 新バージョンをデプロイ（イミュータブルなため上書きは不可）
  2. TransferPolicy を新しいパッケージで再初期化
  3. フロントエンドの設定を更新
- データの損失なし（既存の NFT は変更されない）

---

## Testing Strategy

### Unit Tests
- `mint_nft` の正常系・異常系
- `place_and_list_core` の正常系・異常系
- エラーケース（空文字列、無効な価格）

### Integration Tests
- testnet での実際のデプロイ
- TransferPolicy の初期化確認
- Kiosk への出品と ItemListed イベントの検証
- フロントエンドからの呼び出し確認

### Test Scenarios
```move
#[test]
fun test_mint_nft_success() { ... }

#[test]
#[expected_failure(abort_code = EEmptyString)]
fun test_mint_with_empty_name() { ... }

#[test]
#[expected_failure(abort_code = EInvalidPrice)]
fun test_list_with_zero_price() { ... }
```

---

## Open Questions

1. **手数料システムの導入時期**: 将来的に kiosk_extension で実装する際、既存の NFT への影響は？
   - **回答待ち**: ロードマップ次第で決定

2. **NFT メタデータの拡張**: 将来的に creator, royalty 情報を追加する場合、構造体の変更が必要か？
   - **回答待ち**: Display の動的更新可能性を調査

3. **マルチネットワーク対応のベストプラクティス**: 環境変数での切り替え方法は？
   - **回答待ち**: フロントエンド実装時に検討
