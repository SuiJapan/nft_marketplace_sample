# 🎓 Sui NFT Marketplace ワークショップガイド

このガイドは、`workshop_nft.move`を使用したSui NFTワークショップの完全な実施手順書です。

---

## 📋 目次

1. [Windows対応について](#windows対応について)
2. [事前準備](#事前準備)
3. [第1部: 基礎編](#第1部-基礎編30分)
4. [第2部: 応用編](#第2部-応用編40分)
5. [第3部: 統合デモ](#第3部-統合デモ20分)
6. [トラブルシューティング](#トラブルシューティング)
7. [参考資料](#参考資料)

---

## 💻 Windows (PowerShell) 対応について

このガイドのコマンドはmacOS/Linux向けに記載されていますが、Windows PowerShellでは以下のルールで実行できます。

### 環境変数の違い

| OS | 環境変数の設定 | 環境変数の参照 |
|----|---------------|---------------|
| **macOS/Linux** | `export VAR=value` | `$VAR` |
| **Windows (PowerShell)** | `$env:VAR="value"` | `$env:VAR` |

### 複数行コマンドの違い

| OS | 行継続文字 |
|----|-----------|
| **macOS/Linux** | `\` (バックスラッシュ) |
| **Windows (PowerShell)** | `` ` `` (バッククォート) |

### 実習コマンドの変換例

**macOS/Linux:**
```bash
sui client call \
  --package $PACKAGE_ID \
  --module workshop_nft \
  --function mint \
  --args "My NFT" "Description" "<img src="https://picsum.photos/300/300">" $CLOCK \
  --gas-budget 10000000
```

**Windows (PowerShell):**
```powershell
sui client call `
  --package $env:PACKAGE_ID `
  --module workshop_nft `
  --function mint `
  --args "My NFT" "Description" "<img src="https://picsum.photos/300/300">" $env:CLOCK `
  --gas-budget 10000000
```

**💡 変換ルール:**
- `\` → `` ` `` (バックスラッシュをバッククォートに)
- `$VAR` → `$env:VAR` (環境変数に`$env:`を追加)

以降のすべてのコマンドは、この変換ルールに従ってPowerShellで実行してください

---

## 🔧 事前準備

### 環境変数の設定

**macOS / Linux:**
```bash
export PACKAGE_ID=0x...  # デプロイしたパッケージID
export CLOCK=0x6  # 共有Clockオブジェクト（固定）
export TRANSFER_POLICY_ID=0x...  # デプロイ時に作成されたTransferPolicy ID（NFT購入に必要）
```

**Windows (PowerShell):**
```powershell
$env:PACKAGE_ID="0x..."  # デプロイしたパッケージID
$env:CLOCK="0x6"  # 共有Clockオブジェクト（固定）
$env:TRANSFER_POLICY_ID="0x..."  # デプロイ時に作成されたTransferPolicy ID（NFT購入に必要）
```

**💡 ヒント:**
- `TRANSFER_POLICY_ID`は、コントラクトデプロイ時のトランザクション結果で確認できます
- `TransferPolicy`オブジェクトを探して、そのIDを設定してください

---

## 📚 第1部: 基礎編（30分）

### 1. Sui NFTとClockの基本

#### 💡 学習ポイント

**Sui NFTの基本構造:**
```move
public struct WorkshopNft has key, store {
    id: UID,               // 一意の識別子
    name: String,          // NFT名
    description: String,   // 説明
    url: String,          // 画像URL
    created_at: u64,      // 作成タイムスタンプ（ミリ秒）
}
```

**Clockオブジェクトとは？**
- Suiブロックチェーン上の「時計」
- 共有オブジェクト（アドレス: `0x6`）
- すべてのトランザクションで利用可能
- `clock.timestamp_ms()`で現在時刻（ミリ秒）を取得

#### 🎯 実習1: シンプルなNFTのミント

```bash
# NFTをミント
sui client call \
  --package $PACKAGE_ID \
  --module workshop_nft \
  --function mint \
  --args "My First NFT" "Workshop Demo NFT" "<img src="https://picsum.photos/300/300">" $CLOCK \
  --gas-budget 10000000
```

**コマンド解説:**
- `--package`: デプロイしたパッケージID
- `--module`: モジュール名（`workshop_nft`）
- `--function`: 呼び出す関数（`mint`）
- `--args`: 引数（名前、説明、URL、Clock）
- `--gas-budget`: ガス上限（MIST単位）

**結果の確認:**
```bash
# ミントされたNFTのオブジェクトIDを記録
export NFT_ID=0x...  # トランザクション結果から取得

# NFTの詳細を確認
sui client object $NFT_ID

# タイムスタンプを確認（created_atフィールド）
sui client object $NFT_ID --json | jq '.data.content.fields.created_at'
```

#### 📊 ビジュアル図解

```
┌─────────────────────────────┐
│   mint() 関数の流れ         │
├─────────────────────────────┤
│ 1. 入力検証                 │
│    - name が空でないか      │
│    - description が空でないか│
│    - url が空でないか       │
├─────────────────────────────┤
│ 2. Clockからタイムスタンプ  │
│    created_at = clock.timestamp_ms()│
├─────────────────────────────┤
│ 3. NFTオブジェクト作成      │
│    WorkshopNft { ... }      │
├─────────────────────────────┤
│ 4. 送信者に転送             │
│    public_transfer(nft, sender)│
└─────────────────────────────┘
```

---

### 2. Kioskマーケットプレイス統合

#### 💡 学習ポイント

**Kioskとは？**
- Sui公式のNFTマーケットプレイス基盤
- NFTの販売・購入・管理を一元化
- `KioskOwnerCap`でオーナー権限を管理

**TransferPolicyの役割:**
- NFT取引のルールを定義
- ロイヤリティ、手数料などを設定可能
- **デプロイ時（`init`関数）に自動作成される**

#### 🎯 実習2: Kioskの作成

```bash
# 自分のKioskを作成
sui client call \
  --package 0x2 \
  --module kiosk \
  --function default \
  --gas-budget 10000000
```

**結果の確認:**
```bash
# KioskとKioskOwnerCapのIDを記録
export KIOSK_ID=0x...
export KIOSK_CAP_ID=0x...

# Kioskの内容を確認
sui client object $KIOSK_ID
```

#### 🎯 実習3: NFTをミント→Kioskにリスト

```bash
# NFTをミントして即座にKioskにリスト（価格: 1 SUI = 1,000,000,000 MIST）
sui client call \
  --package $PACKAGE_ID \
  --module workshop_nft \
  --function mint_and_list \
  --args $KIOSK_ID $KIOSK_CAP_ID "Shop NFT" "For Sale in Kiosk" "https://example.com/shop.png" 1000000000 $CLOCK \
  --gas-budget 10000000
```

**コマンド解説:**
- 価格は`1000000000` MIST = 1 SUI
- `mint_and_list`は1トランザクションでミント→リストを実行

**Kioskの確認:**
```bash
# Kioskに入っているNFTを確認
sui client object $KIOSK_ID --json | jq '.content.fields'
```

#### 🎯 実習4: 他の人のKioskからNFTを購入

**学習ポイント:**

Kioskの購入機能を使うことで、リストされているNFTを誰でも購入できます。

**購入の流れ:**
1. 購入したいNFTがリストされているKiosk IDを確認
2. NFT IDと価格を確認
3. `purchase_and_resolve`関数で購入とTransferPolicyの解決を同時実行
4. NFTが自動的に購入者のウォレットに転送される

**コマンド例:**

```bash
# 他の人のKioskからNFTを購入
# 注意: 実際に購入するには、NFTの価格分のSUIが必要です

# 例: 1 SUIで販売されているNFTを購入
sui client call \
  --package $PACKAGE_ID \
  --module workshop_nft \
  --function purchase_and_resolve \
  --args <SELLER_KIOSK_ID> <NFT_ID> <TRANSFER_POLICY_ID> \
  --gas-budget 10000000
```

**引数の説明:**
- `<SELLER_KIOSK_ID>`: 購入したいNFTが出品されているKioskのID
- `<NFT_ID>`: 購入したいNFTのID
- `<TRANSFER_POLICY_ID>`: WorkshopNft用のTransferPolicy ID（デプロイ時に作成されたもの）

**購入後の確認:**
```bash
# 自分のウォレットにNFTが転送されたことを確認
sui client objects

# NFTの詳細を確認
sui client object <NFT_ID>
```

**💡 ヒント:**
- 購入前に、Kioskの内容を確認して価格をチェックしましょう
- 購入には、NFTの価格 + ガス代が必要です
- `purchase_and_resolve`は、購入とTransferPolicyの解決を1トランザクションで実行します

**TypeScript SDK での購入例:**
```typescript
import { TransactionBlock } from '@mysten/sui.js/transactions';

const tx = new TransactionBlock();

// 購入処理
tx.moveCall({
  target: `${PACKAGE_ID}::workshop_nft::purchase_and_resolve`,
  arguments: [
    tx.object(SELLER_KIOSK_ID),
    tx.pure(NFT_ID, 'address'),
    tx.object(TRANSFER_POLICY_ID),
  ],
});

// トランザクションを実行
const result = await client.signAndExecuteTransactionBlock({
  signer: keypair,
  transactionBlock: tx,
});
```

#### 📊 ビジュアル図解

```
┌─────────────────────────────┐
│   Kiosk統合の全体像         │
├─────────────────────────────┤
│ 1. TransferPolicy作成       │
│    init()で自動作成         │
│    ↓                        │
│    Policy + PolicyCap       │
├─────────────────────────────┤
│ 2. Kiosk作成                │
│    kiosk::default()         │
│    ↓                        │
│    Kiosk + KioskOwnerCap    │
├─────────────────────────────┤
│ 3. NFTミント＆リスト        │
│    mint_and_list()          │
│    ↓                        │
│    NFT → Kiosk (price付き)  │
├─────────────────────────────┤
│ 4. 購入処理                 │
│    purchase_and_resolve()   │
│    ↓                        │
│    a. Kioskから購入         │
│    b. 代金を支払い          │
│    c. TransferPolicy解決    │
│    d. NFT → 購入者          │
└─────────────────────────────┘

購入フローの詳細:
┌──────────────┐
│  購入者      │
└──────┬───────┘
       │ 1. purchase_and_resolve() を呼び出し
       ↓
┌──────────────┐
│  Kiosk       │
├──────────────┤
│ - NFT (price)│ 2. 価格チェック & NFT取り出し
└──────┬───────┘
       │ 3. 代金支払い（SUI）
       ↓
┌──────────────┐
│TransferPolicy│ 4. TransferRequestを解決
└──────┬───────┘
       │ 5. 所有権転送を承認
       ↓
┌──────────────┐
│  購入者      │ 6. NFTを受け取り
└──────────────┘
```

---

## 🚀 第2部: 応用編（40分）

### 3. Dynamic Fields - 動的メタデータ拡張

#### 💡 学習ポイント

**Dynamic Fieldとは？**
- NFT作成**後**に追加できる柔軟なデータ格納機能
- 構造体定義を変更せずにオブジェクトを拡張
- 格納される値は`store`アビリティのみが必要
- 外部からIDで直接アクセス不可（NFT経由でのみアクセス）

**Metadata構造体:**
```move
public struct Metadata has store {
    rarity: u8,    // レアリティレベル（1-4）
    level: u64,    // アイテムレベル
}
```

**レアリティの定義:**
- `1` = Common（コモン）
- `2` = Rare（レア）
- `3` = Epic（エピック）
- `4` = Legendary（レジェンダリー）

#### 🎯 実習4: NFTにメタデータを追加

```bash
# まず新しいNFTをミント
sui client call \
  --package $PACKAGE_ID \
  --module workshop_nft \
  --function mint \
  --args "Rare Sword" "A powerful blade" "<img src="https://picsum.photos/300/300">" $CLOCK \
  --gas-budget 10000000

# NFT_IDを記録
export NFT_WITH_METADATA=0x...

# メタデータを追加（rarity=3(Epic), level=10）
sui client call \
  --package $PACKAGE_ID \
  --module workshop_nft \
  --function add_metadata \
  --args $NFT_WITH_METADATA 3 10 \
  --gas-budget 10000000
```

#### 🎯 実習5: メタデータの読み取り

```bash
# メタデータを読み取り（View関数）
sui client call \
  --package $PACKAGE_ID \
  --module workshop_nft \
  --function get_metadata \
  --args $NFT_WITH_METADATA \
  --gas-budget 10000000

# メタデータの存在確認
sui client call \
  --package $PACKAGE_ID \
  --module workshop_nft \
  --function has_metadata \
  --args $NFT_WITH_METADATA \
  --gas-budget 10000000
```

#### 🎯 実習6: レベルアップシミュレーション

```bash
# レベルを10→25に更新（ゲーム内での成長を模擬）
sui client call \
  --package $PACKAGE_ID \
  --module workshop_nft \
  --function update_metadata_level \
  --args $NFT_WITH_METADATA 25 \
  --gas-budget 10000000

# 更新後のメタデータを確認
sui client call \
  --package $PACKAGE_ID \
  --module workshop_nft \
  --function get_metadata \
  --args $NFT_WITH_METADATA \
  --gas-budget 10000000
```

#### 📊 ビジュアル図解

```
┌─────────────────────────────┐
│   NFT Object (before)       │
├─────────────────────────────┤
│ id: UID                     │
│ name: "Rare Sword"          │
│ created_at: 1234567890      │
└─────────────────────────────┘
           ↓ add_metadata()
┌─────────────────────────────┐
│   NFT Object (after)        │
├─────────────────────────────┤
│ id: UID                     │
│ name: "Rare Sword"          │
│ created_at: 1234567890      │
├─────────────────────────────┤
│ Dynamic Fields:             │
│   "metadata" → Metadata {   │ ← 追加！
│     rarity: 3,              │
│     level: 10               │
│   }                         │
└─────────────────────────────┘
```

---

### 4. Dynamic Object Fields - コンポーザブルNFT

#### 💡 学習ポイント

**Dynamic Object Fieldとは？**
- 独立した**別のオブジェクト**をNFTに添付
- 格納されるオブジェクトは`key` + `store`アビリティが必要
- アクセサリーは独自のIDでアクセス可能なまま
- ゲームの装備システム、コンポーザブルNFTに最適

**Accessory構造体:**
```move
public struct Accessory has key, store {
    id: UID,                      // 独立した識別子
    accessory_type: String,       // タイプ（例: "hat", "weapon"）
    bonus_value: u64,             // ボーナス値
}
```

**Dynamic FieldとDynamic Object Fieldの違い:**

| 特徴 | Dynamic Field | Dynamic Object Field |
|------|---------------|---------------------|
| 必要なアビリティ | `store` | `key` + `store` |
| 独立したID | なし | あり |
| 外部アクセス | NFT経由のみ | IDで直接可能 |
| 用途 | メタデータ、設定値 | 装備、子NFT |

#### 🎯 実習7: アクセサリーをNFTに添付

```bash
# まず新しいNFTをミント
sui client call \
  --package $PACKAGE_ID \
  --module workshop_nft \
  --function mint \
  --args "Warrior" "Battle-ready character" "https://example.com/warrior.png" $CLOCK \
  --gas-budget 10000000

# NFT_IDを記録
export NFT_WITH_ACCESSORY=0x...

# アクセサリーを作成して添付
# 注意: CLIからAccessoryオブジェクトを直接作成するのは複雑なため、
# 実際にはmint_full_featured_nftを使用するのが簡単です（後述）
```

**アクセサリー添付の流れ（コード内部）:**
```move
// 1. Accessoryオブジェクトを作成
let accessory = Accessory {
    id: object::new(ctx),
    accessory_type: string::utf8(b"Magic Sword"),
    bonus_value: 50,
};

// 2. NFTに添付（スロット名: "weapon"）
dof::add(&mut nft.id, b"weapon", accessory);
```

#### 🎯 実習8: フル機能NFTの作成（統合デモ）

```bash
# すべての機能を持つNFTを一度に作成
sui client call \
  --package $PACKAGE_ID \
  --module workshop_nft \
  --function mint_full_featured_nft \
  --args \
    "Legendary Warrior" \
    "Epic battle-tested NFT with full stats and equipment" \
    "https://example.com/legendary.png" \
    4 \
    50 \
    "Dragon Armor" \
    100 \
    $CLOCK \
  --gas-budget 10000000
```

**引数の説明:**
1. `"Legendary Warrior"` - NFT名
2. `"Epic battle..."` - 説明
3. `"https://..."` - 画像URL
4. `4` - レアリティ（4=Legendary）
5. `50` - レベル
6. `"Dragon Armor"` - アクセサリータイプ
7. `100` - アクセサリーボーナス値
8. `$CLOCK` - Clockオブジェクト

**結果の確認:**
```bash
# NFT_IDを記録
export FULL_FEATURED_NFT=0x...

# NFTの全データを確認
sui client object $FULL_FEATURED_NFT --json | jq '.'

# メタデータを確認
sui client call \
  --package $PACKAGE_ID \
  --module workshop_nft \
  --function get_metadata \
  --args $FULL_FEATURED_NFT \
  --gas-budget 10000000

# アクセサリーの存在確認
sui client call \
  --package $PACKAGE_ID \
  --module workshop_nft \
  --function has_accessory \
  --args $FULL_FEATURED_NFT '"main_accessory"' \
  --gas-budget 10000000
```

#### 📊 ビジュアル図解

```
┌─────────────────────────────────────┐
│   Full Featured NFT Object          │
├─────────────────────────────────────┤
│ id: UID                             │
│ name: "Legendary Warrior"           │
│ description: "Epic battle..."       │
│ url: "https://..."                  │
│ created_at: 1234567890              │ ← Clock統合
├─────────────────────────────────────┤
│ Dynamic Fields:                     │
│   "metadata" → Metadata {           │ ← Dynamic Field
│     rarity: 4,          (Legendary) │
│     level: 50                       │
│   }                                 │
├─────────────────────────────────────┤
│ Dynamic Object Fields:              │
│   "main_accessory" → Accessory {    │ ← Dynamic Object Field
│     id: 0xABC...,       (独立ID)   │
│     accessory_type: "Dragon Armor", │
│     bonus_value: 100                │
│   }                                 │
└─────────────────────────────────────┘
```

---

## 🎯 第3部: 統合デモ（20分）

### 実践課題: オリジナルNFTコレクションの作成

参加者が自分でNFTコレクションを作成する実習です。

#### 📋 課題1（初級）: 基本NFTの作成

**目標:** 自分の名前でNFTをミントし、タイムスタンプを確認

```bash
# あなたの名前でNFTをミント
sui client call \
  --package $PACKAGE_ID \
  --module workshop_nft \
  --function mint \
  --args "Your Name NFT" "Created by [Your Name]" "https://example.com/your-nft.png" $CLOCK \
  --gas-budget 10000000

# タイムスタンプを確認
export MY_NFT=0x...
sui client object $MY_NFT --json | jq '.data.content.fields.created_at'
```

**チェックポイント:**
- [ ] NFTが正常にミントされた
- [ ] タイムスタンプが記録されている
- [ ] 自分のウォレットにNFTが転送された

---

#### 📋 課題2（中級）: メタデータ付きNFT

**目標:** レアリティとレベルを持つNFTを作成し、レベルアップを体験

```bash
# 1. NFTをミント
sui client call \
  --package $PACKAGE_ID \
  --module workshop_nft \
  --function mint \
  --args "Magic Staff" "Wizard's enchanted staff" "https://example.com/staff.png" $CLOCK \
  --gas-budget 10000000

export MAGIC_STAFF=0x...

# 2. メタデータを追加（rarity=2(Rare), level=5）
sui client call \
  --package $PACKAGE_ID \
  --module workshop_nft \
  --function add_metadata \
  --args $MAGIC_STAFF 2 5 \
  --gas-budget 10000000

# 3. 初期メタデータを確認
sui client call \
  --package $PACKAGE_ID \
  --module workshop_nft \
  --function get_metadata \
  --args $MAGIC_STAFF \
  --gas-budget 10000000

# 4. レベルを10に更新
sui client call \
  --package $PACKAGE_ID \
  --module workshop_nft \
  --function update_metadata_level \
  --args $MAGIC_STAFF 10 \
  --gas-budget 10000000

# 5. 更新後のメタデータを確認
sui client call \
  --package $PACKAGE_ID \
  --module workshop_nft \
  --function get_metadata \
  --args $MAGIC_STAFF \
  --gas-budget 10000000
```

**チェックポイント:**
- [ ] メタデータが正しく追加された（rarity=2, level=5）
- [ ] レベルが10に更新された
- [ ] `get_metadata`で値が確認できた

---

#### 📋 課題3（上級）: コレクションの販売

**目標:** 複数のNFTを作成し、Kioskで販売

```bash
# 1. NFTコレクション（3点）を作成してKioskにリスト
sui client call \
  --package $PACKAGE_ID \
  --module workshop_nft \
  --function mint_and_list \
  --args $KIOSK_ID $KIOSK_CAP_ID "Collection #1" "First NFT in my collection" "https://example.com/c1.png" 500000000 $CLOCK \
  --gas-budget 10000000

sui client call \
  --package $PACKAGE_ID \
  --module workshop_nft \
  --function mint_and_list \
  --args $KIOSK_ID $KIOSK_CAP_ID "Collection #2" "Second NFT in my collection" "https://example.com/c2.png" 750000000 $CLOCK \
  --gas-budget 10000000

sui client call \
  --package $PACKAGE_ID \
  --module workshop_nft \
  --function mint_and_list \
  --args $KIOSK_ID $KIOSK_CAP_ID "Collection #3" "Third NFT in my collection" "https://example.com/c3.png" 1000000000 $CLOCK \
  --gas-budget 10000000

# 2. Kioskの内容を確認
sui client object $KIOSK_ID --json | jq '.data.content.fields'
```

**価格設定:**
- Collection #1: 0.5 SUI（500,000,000 MIST）
- Collection #2: 0.75 SUI（750,000,000 MIST）
- Collection #3: 1.0 SUI（1,000,000,000 MIST）

**チェックポイント:**
- [ ] 3つのNFTがKioskに追加された
- [ ] 各NFTに正しい価格が設定された
- [ ] Kioskオブジェクトで確認できた

**📝 発展課題: 他の参加者のNFTを購入してみよう**

ワークショップの参加者同士で、お互いのKioskから購入することができます。

```bash
# 1. 購入したい参加者のKiosk IDとNFT IDを教えてもらう
# 例:
# SELLER_KIOSK_ID=0xabc...
# TARGET_NFT_ID=0xdef...

# 2. そのKioskの内容を確認（価格をチェック）
sui client object <SELLER_KIOSK_ID> --json | jq '.data.content.fields'

# 3. 購入を実行
sui client call \
  --package $PACKAGE_ID \
  --module workshop_nft \
  --function purchase_and_resolve \
  --args <SELLER_KIOSK_ID> <TARGET_NFT_ID> <TRANSFER_POLICY_ID> \
  --gas-budget 10000000

# 4. 購入したNFTを確認
sui client objects
sui client object <TARGET_NFT_ID>
```

**💡 ヒント:**
- TRANSFER_POLICY_IDは、パッケージをデプロイした時に作成されたものを使用します
- 環境変数として設定しておくと便利です: `export TRANSFER_POLICY_ID=0x...`
- 購入には、NFTの価格分のSUIが必要です（残高を確認: `sui client gas`）
- 複数人でワークショップを行う場合は、お互いのKiosk IDを共有しましょう

**発展チェックポイント:**
- [ ] 他の参加者のKioskを確認できた
- [ ] 購入に必要な情報（Kiosk ID、NFT ID、価格）を取得できた
- [ ] 実際にNFTを購入し、所有権が移転された

---

#### 📋 課題4（統合）: 最強のNFTを作成

**目標:** すべての機能を持つ最強のNFTを作成

```bash
# フル機能NFTを作成
sui client call \
  --package $PACKAGE_ID \
  --module workshop_nft \
  --function mint_full_featured_nft \
  --args \
    "Ultimate Champion" \
    "The most powerful NFT with all features" \
    "https://example.com/ultimate.png" \
    4 \
    100 \
    "Infinity Gauntlet" \
    999 \
    $CLOCK \
  --gas-budget 10000000

# NFTの詳細を確認
export ULTIMATE_NFT=0x...
sui client object $ULTIMATE_NFT --json | jq '.'

# メタデータを確認
sui client call \
  --package $PACKAGE_ID \
  --module workshop_nft \
  --function get_metadata \
  --args $ULTIMATE_NFT \
  --gas-budget 10000000
```

**作成されるNFTの仕様:**
- **名前:** Ultimate Champion
- **レアリティ:** 4（Legendary）
- **レベル:** 100
- **アクセサリー:** Infinity Gauntlet（ボーナス+999）
- **タイムスタンプ:** 自動記録

**チェックポイント:**
- [ ] NFTが正常に作成された
- [ ] メタデータが正しく設定された（rarity=4, level=100）
- [ ] アクセサリーが添付された
- [ ] タイムスタンプが記録された

---

## 🔧 トラブルシューティング

### よくあるエラーと解決策

#### ❌ `EEmptyString` エラー

**エラーメッセージ:**
```
Execution Error: Move execution failed with status: ABORTED { code: 1 }
```

**原因:** 名前、説明、URLのいずれかが空文字列

**解決策:**
```bash
# ❌ 間違い
sui client call ... --args "" "description" "url" ...

# ✅ 正しい
sui client call ... --args "My NFT" "description" "url" ...
```

---

#### ❌ `EInvalidPrice` エラー

**エラーメッセージ:**
```
Execution Error: Move execution failed with status: ABORTED { code: 2 }
```

**原因:** 価格が0または負の値

**解決策:**
```bash
# ❌ 間違い
sui client call ... --args ... 0 ...

# ✅ 正しい（最低1 MIST = 0.000000001 SUI）
sui client call ... --args ... 1000000000 ...  # 1 SUI
```

---

#### ❌ Dynamic Field not found エラー

**エラーメッセージ:**
```
Field does not exist
```

**原因:** メタデータがまだ追加されていない

**解決策:**
```bash
# 先にメタデータを追加
sui client call \
  --package $PACKAGE_ID \
  --module workshop_nft \
  --function add_metadata \
  --args $NFT_ID 1 1 \
  --gas-budget 10000000

# その後、get_metadataを実行
sui client call \
  --package $PACKAGE_ID \
  --module workshop_nft \
  --function get_metadata \
  --args $NFT_ID \
  --gas-budget 10000000
```

---

#### ❌ 環境変数が設定されていない

**エラーメッセージ:**
```
invalid object id
```

**原因:** `$PACKAGE_ID`などの環境変数が未設定

**解決策:**
```bash
# 環境変数を確認
echo $PACKAGE_ID
echo $CLOCK

# 未設定の場合は設定
export PACKAGE_ID=0x...
export CLOCK=0x6
```

---

### デバッグコマンド集

```bash
# アカウント情報の確認
sui client active-address

# 所有オブジェクトの一覧
sui client objects

# 特定のオブジェクトの詳細
sui client object <OBJECT_ID>

# トランザクション履歴
sui client transactions

# ガス残高の確認
sui client gas

# ネットワーク接続の確認
sui client active-env
```

---

## 📚 参考資料

### Sui Move公式ドキュメント

- [Sui Move Book](https://move-book.com/)
- [Sui Documentation](https://docs.sui.io/)
- [Kiosk Guide](https://docs.sui.io/standards/kiosk)
- [Dynamic Fields](https://docs.sui.io/concepts/dynamic-fields)

### コード例

- [workshop_nft.move](./sources/workshop_nft.move) - 本ワークショップのコントラクト
- [contract_spec.md](./contract_spec.md) - 要件定義

### コミュニティ

- [Sui Discord](https://discord.gg/sui)
- [Sui Forum](https://forums.sui.io/)
- [Sui GitHub](https://github.com/MystenLabs/sui)

---

## 🎓 学習の到達目標

このワークショップを完了すると、以下のスキルが身につきます：

### ✅ 基礎スキル
- [ ] Sui CLIの基本操作
- [ ] NFTのミントと転送
- [ ] Clockオブジェクトの使用
- [ ] トランザクションの実行と確認

### ✅ 応用スキル
- [ ] Kiosk統合とマーケットプレイス機能
- [ ] TransferPolicyの理解
- [ ] Dynamic Fieldsの操作
- [ ] Dynamic Object Fieldsの活用

### ✅ 実践スキル
- [ ] フル機能NFTの設計と実装
- [ ] エラーハンドリング
- [ ] デバッグ手法
- [ ] ベストプラクティスの理解

---

## 💡 次のステップ

ワークショップ後の学習パス：

1. **フロントエンド統合**
   - Sui TypeScript SDKの学習
   - dAppフロントエンドの構築
   - ウォレット接続の実装

2. **高度なMove機能**
   - カスタムTransferPolicyの実装
   - Capabilityパターンの学習
   - モジュール間の連携

3. **プロダクション展開**
   - Mainnetへのデプロイ
   - セキュリティ監査
   - ガス最適化

4. **応用プロジェクト**
   - ゲームアイテムシステム
   - メタバースアセット
   - DeFi統合NFT

---

**Happy Building on Sui! 🚀**
