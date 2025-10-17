# 要件定義（コントラクト：Sui Move）

## 目的
- `WorkshopNft` を mint できる最小機能。
- （任意）受け取った Kiosk/Cap に NFT を置く（place）までサポート。
- **TransferPolicy<WorkshopNft> の初期化（発行者が1回実行）**を提供。

## 外部標準への依存
- Kiosk 標準（`0x2::kiosk`）: place / list / purchase / delist とイベント群を利用。:contentReference[oaicite:1]{index=1}
- TransferPolicy 標準（`0x2::transfer_policy`）: `default<T>` でポリシー作成・共有、購入時の `confirm_request`。:contentReference[oaicite:2]{index=2}
- Display 標準（`0x2::display`）: フロントが `showDisplay: true` で表示用メタを取得。

## Move 2024 可視性方針
- 実処理は `public(package)` を既定、PTB 入口は薄い `entry` に限定。
- `entry` は引数検証／TxContext／イベントのみ、ロジックは委譲。

## 型・モジュール
- モジュール: `workshop_nft`
- 構造体: `struct WorkshopNft has key, store { id: UID, name: String, description: String, url: String }`
- （任意）Display 設定エンドポイント。

## 提供関数（最小）
1. **Policy 初期化（発行者のみ1回）**
   - `entry fun init_transfer_policy(publisher: &Publisher, ctx: &mut TxContext)`
   - 目的: `TransferPolicy<WorkshopNft>` を作成・共有（または凍結）し、Kiosk 取引を可能化。:contentReference[oaicite:3]{index=3}

2. **Mint**
   - `public(package) fun mint_nft(name: String, description: String, url: String, ctx: &mut TxContext): WorkshopNft`

3. **Mint→Kiosk に入れる（place）**
   - 方式A（既存 Kiosk/Cap を引数でもらう）
     - `public(package) fun place_core(k: &mut Kiosk, cap: &KioskOwnerCap, nft: WorkshopNft)`
     - `entry fun mint_and_place(k: &mut Kiosk, cap: &KioskOwnerCap, name: String, description: String, url: String, ctx: &mut TxContext)`
   - 方式B（自動作成して入れる・任意）
     - `entry fun mint_and_place_autocreate(name: String, description: String, url: String, ctx: &mut TxContext)`
     - 内部で `kiosk::new` → place → Cap を sender に転送 → Kiosk を共有化（`share_object`）。`kiosk::default` 相当の流れを自前で構成。:contentReference[oaicite:4]{index=4}

## 非機能
- `sui move test` によるユニットテスト。
- 価格はフロントで扱い（MIST 単位）※コントラクト側は place のみで list/price は扱わない方針。
- Testnet を既定ターゲット（Mainnetでも可）。
