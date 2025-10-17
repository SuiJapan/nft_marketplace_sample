# Implementation Tasks

## 1. Environment Setup
- [x] 1.1 Move.toml の依存関係を更新（Sui Framework の追加）
- [x] 1.2 contract/sources/contract.move を workshop_nft.move にリネーム

## 2. Core NFT Structure
- [x] 2.1 WorkshopNft 構造体を定義（id, name, description, url フィールド）
- [x] 2.2 init 関数で Display<WorkshopNft> を作成・設定
- [x] 2.3 Display に name, description, image_url フィールドをマッピング

## 3. NFT Mint Implementation
- [x] 3.1 `public(package) fun mint_nft()` の実装
  - WorkshopNft オブジェクトの生成
  - 入力検証（空文字列チェック）
- [x] 3.2 `entry fun mint()` の実装
  - mint_nft の呼び出し
  - NFT の transfer

## 4. TransferPolicy Implementation
- [x] 4.1 `entry fun init_transfer_policy()` の実装
  - Publisher の受け取り
  - transfer_policy::new<WorkshopNft> の呼び出し（ルールなし）
  - TransferPolicy の共有
  - TransferPolicyCap の transfer

## 5. Kiosk Integration
- [x] 5.1 `public(package) fun place_and_list_core()` の実装
  - kiosk::place_and_list の呼び出し
  - 価格検証（0 以下のチェック）
- [x] 5.2 `entry fun mint_and_list()` の実装
  - mint_nft の呼び出し
  - place_and_list_core の呼び出し

## 6. Error Handling
- [x] 6.1 エラーコード定数の定義
  - EEmptyString: 空文字列エラー
  - EInvalidPrice: 無効な価格エラー
- [x] 6.2 各関数にエラーチェックを追加

## 7. Testing
- [x] 7.1 単体テストの作成（contract/tests/workshop_nft_tests.move）
  - mint 機能のテスト
  - TransferPolicy 初期化のテスト
  - Kiosk 出品のテスト
- [x] 7.2 `sui move test` でテスト実行・成功確認

## 8. Integration Testing
- [ ] 8.1 testnet/devnet へのデプロイ
- [ ] 8.2 init_transfer_policy の実行
- [ ] 8.3 mint_and_list の実行
- [ ] 8.4 ItemListed イベントの確認

## 9. Documentation
- [x] 9.1 コード内のコメント追加（関数の説明、パラメータ、戻り値）
- [x] 9.2 README.md の更新（デプロイ手順、使用方法）
