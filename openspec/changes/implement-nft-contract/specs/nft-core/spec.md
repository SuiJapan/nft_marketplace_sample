# NFT Core Specification Deltas

## ADDED Requirements

### Requirement: NFT Structure Definition
コントラクトは WorkshopNft 構造体を定義し、Sui の key と store アビリティを持つ SHALL。

#### Scenario: WorkshopNft 構造体の定義
- **WHEN** WorkshopNft 構造体が定義される
- **THEN** 以下のフィールドを持つこと:
  - `id: UID`: オブジェクトの一意識別子
  - `name: String`: NFT の名前
  - `description: String`: NFT の説明
  - `url: String`: NFT の画像 URL
- **AND** `key, store` アビリティを持つこと

#### Scenario: Display 標準の設定
- **WHEN** モジュールが初期化される（`init` 関数）
- **THEN** Display<WorkshopNft> オブジェクトが作成されること
- **AND** 以下のフィールドが Display に設定されること:
  - `name`: NFT 名の表示
  - `description`: NFT 説明の表示
  - `image_url`: NFT 画像 URL の表示

---

### Requirement: NFT Mint Functionality
コントラクトは NFT を mint する機能を提供する SHALL。実処理は `public(package)` 関数で実装し、外部からは `entry` 関数経由で呼び出す SHALL。

#### Scenario: mint_nft（実処理）の実装
- **WHEN** `mint_nft(name, description, url, ctx)` が呼ばれる
- **THEN** 新しい WorkshopNft オブジェクトが作成されること
- **AND** WorkshopNft オブジェクトが返却されること
- **AND** `public(package)` 可視性を持つこと

#### Scenario: mint（entry 関数）の実装
- **WHEN** `mint(name, description, url, ctx)` が PTB から呼ばれる
- **THEN** `mint_nft` を呼び出すこと
- **AND** 作成された NFT を呼び出し元に transfer すること
- **AND** `entry` 可視性を持つこと

---

### Requirement: TransferPolicy Initialization
コントラクトは TransferPolicy<WorkshopNft> を初期化する機能を提供する SHALL。この機能はデプロイ後に管理者が 1 回だけ実行する SHALL。

#### Scenario: init_transfer_policy の実装
- **WHEN** `init_transfer_policy(publisher, ctx)` が管理者により呼ばれる
- **THEN** `sui::transfer_policy::default<WorkshopNft>` を使用して TransferPolicy と TransferPolicyCap を作成すること
- **AND** TransferPolicy を `public_share_object` で共有すること
- **AND** TransferPolicyCap を呼び出し元に transfer すること
- **AND** `entry` 可視性を持つこと

#### Scenario: TransferPolicy が存在しない場合の制約
- **WHEN** TransferPolicy<WorkshopNft> が初期化されていない
- **THEN** Kiosk での WorkshopNft の売買ができないこと

---

### Requirement: Kiosk Integration
コントラクトは Kiosk への NFT 配置と出品を行う機能を提供する SHALL。

#### Scenario: place_and_list_core（実処理）の実装
- **WHEN** `place_and_list_core(kiosk, kiosk_cap, nft, price, ctx)` が呼ばれる
- **THEN** `kiosk::place_and_list` を使用して NFT を Kiosk に配置し出品すること
- **AND** 価格は MIST 単位で指定されること（1 SUI = 1,000,000,000 MIST）
- **AND** `public(package)` 可視性を持つこと

#### Scenario: mint_and_list（entry 関数）の実装
- **WHEN** `mint_and_list(kiosk, kiosk_cap, name, description, url, price, ctx)` が PTB から呼ばれる
- **THEN** `mint_nft` で NFT を作成すること
- **AND** `place_and_list_core` で Kiosk に配置・出品すること
- **AND** `entry` 可視性を持つこと

#### Scenario: ItemListed イベントの発行
- **WHEN** NFT が Kiosk に出品される
- **THEN** Kiosk モジュールから `ItemListed<WorkshopNft>` イベントが発行されること
- **AND** イベントには以下の情報が含まれること:
  - `kiosk`: Kiosk のオブジェクト ID
  - `id`: NFT のオブジェクト ID
  - `price`: 出品価格（MIST 単位）

---

### Requirement: Move 2024 Visibility Policy Compliance
コントラクトは Move 2024 の可視性ポリシーに準拠する SHALL。

#### Scenario: 可視性の分離
- **WHEN** コントラクトが設計される
- **THEN** 実処理は `public(package)` または `private` で実装されること
- **AND** 外部インターフェースは `entry` 関数で提供されること
- **AND** `entry` 関数は引数チェックとイベント発行のみを行い、実処理を `public(package)` 関数に委譲すること

#### Scenario: PTB からの呼び出し
- **WHEN** Programmable Transaction Block から関数が呼ばれる
- **THEN** `entry` または `public` 可視性を持つ関数のみが呼び出し可能であること

---

### Requirement: Multi-Network Support
コントラクトは testnet、devnet、mainnet のいずれのネットワークでも動作する SHALL。

#### Scenario: ネットワーク非依存の実装
- **WHEN** コントラクトがデプロイされる
- **THEN** ハードコードされたアドレスや環境依存のコードが含まれないこと
- **AND** Move.toml で適切なアドレス設定が行われること

---

### Requirement: Error Handling
コントラクトは適切なエラーハンドリングを行う SHALL。

#### Scenario: 無効な入力の検証
- **WHEN** 空の文字列が name, description, url に渡される
- **THEN** エラーコードと共にアボートすること

#### Scenario: 無効な価格の検証
- **WHEN** 0 または負の価格が指定される
- **THEN** エラーコードと共にアボートすること
