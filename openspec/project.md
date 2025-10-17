# Project Context

## Purpose

本プロジェクトは、Sui ブロックチェーン上で動作する NFT マーケットプレイスです。以下の目的を持ちます：

- **最小構成の NFT を mint** し、**TransferPolicy** を初期化して **Kiosk 取引を許可**
- Sui の標準 Kiosk インフラを活用した分散型 NFT マーケットプレイスの構築
- ワークショップ・学習用途に適したシンプルで拡張可能なアーキテクチャ

### 主要機能

1. **NFT の mint**：WorkshopNft の発行
2. **出品機能**：mint と同時に Kiosk へ出品（`mint_and_list`）
3. **一覧表示**：Kiosk に出品された NFT を一覧表示
4. **購入機能**：ウォレット接続による NFT 購入
5. **リアルタイム同期**：イベント監視による最新出品の反映

## Tech Stack

### Backend (Sui Move)

- **Sui Move**（Move 2024 仕様準拠）
  - 可視性ポリシー：`private` / `public(package)` 優先
  - entry 関数は薄く実装し、実処理は `public(package)` に委譲
- **Kiosk 標準**：place / list / purchase API による NFT 取引
- **TransferPolicy 標準**：型 `T` のトレード可否制御
- **Display 標準**：NFT メタデータのフロント表示サポート

### Frontend (Next.js)

- **Next.js 14+**（App Router）
- **TypeScript**
- **React 18**
- **Node 20+**
- **@mysten/sui**：SuiClient、JSON-RPC、subscribeEvent
- **@mysten/kiosk**：KioskClient、KioskTransaction、purchaseAndResolve
- **Sui dApp Kit**：ウォレット接続、RPC フック、ネットワーク切替

## Project Conventions

### Code Style

#### Move（Sui Move）

**Move 2024 可視性ポリシー**
- **外部公開最小化**：まず `private` / `public(package)`、必要時のみ `public`
- **entry は薄く**：引数チェック・イベント発行・`TxContext` のみ、実処理は `public(package)` に委譲
- **PTB 呼出対象**：`entry` / `public` のみが Programmable Transaction Block から呼出可能

**命名規則**
- モジュール名：`snake_case`（例：`workshop_nft`）
- 構造体：`PascalCase`（例：`WorkshopNft`）
- 関数：`snake_case`（例：`mint_nft`, `place_and_list_core`）

#### TypeScript/Next.js

**App Router パターン**
- サーバーコンポーネントとクライアントコンポーネントの適切な分離
- `'use client'` ディレクティブの明示的な使用

**命名規則**
- コンポーネント：`PascalCase`（例：`NFTCard`, `WalletButton`）
- ユーティリティ関数：`camelCase`（例：`getSuiClient`, `formatMist`）
- 定数：`UPPER_SNAKE_CASE`（例：`MIST_PER_SUI`）

**価格表示規約**
- 内部計算：MIST 単位（1 SUI = 1,000,000,000 MIST）
- UI 表示：SUI 単位（`MIST_PER_SUI` で変換）

### Architecture Patterns

#### Move 側アーキテクチャ

**モジュール構成**
```
packages/contracts/sources/
  workshop_nft.move       # NFT 定義と mint ロジック
```

**主要構造体**
- `WorkshopNft has key, store`：NFT 本体
- Display 標準を使用してメタデータを管理

**関数設計**
- `public(package) fun mint_nft(...)`：NFT 生成の実処理
- `public(package) fun place_and_list_core(...)`：Kiosk 出品の実処理
- `entry fun mint(...)`：外部呼出用の薄い entry
- `entry fun init_transfer_policy(...)`：TransferPolicy 初期化（デプロイ後 1 回実行）
- `entry fun mint_and_list(...)`：mint と出品を一括実行

**Kiosk 連携**
- `kiosk::place` / `kiosk::list` / `kiosk::place_and_list` を使用
- 必要な参照（`&mut Kiosk`、`&KioskOwnerCap`）を entry に渡す

#### Frontend 側アーキテクチャ

**データフロー**
1. **初回ロード**：`queryEvents` で直近の `ItemListed` イベントを取得
   - 型指定フィルタ例：`MoveEventType: "0x2::kiosk::ItemListed<0x<PKG>::workshop_nft::WorkshopNft>"`
   - これにより `WorkshopNft` 型の出品イベントのみを抽出可能
2. **リアルタイム更新**：`subscribeEvent` でイベントを購読し一覧を更新
   - 不安定時は `queryEvents` ポーリングへ自動フォールバック（本番環境での安定性考慮）
3. **メタデータ取得**：Display を `showDisplay: true` で取得

**イベント取得の実装例**
```typescript
import { SuiClient, getFullnodeUrl } from '@mysten/sui/client';

const client = new SuiClient({ url: getFullnodeUrl('testnet') });

// 型指定フィルタで WorkshopNft の出品イベントのみ取得
const res = await client.queryEvents({
  query: {
    MoveEventType: '0x2::kiosk::ItemListed<0x<PKG>::workshop_nft::WorkshopNft>',
  },
  order: 'descending',
  limit: 50,
});
// res.data[] に { id, kiosk, price } などが含まれる
```

**Display 取得の実装例**
```typescript
const obj = await client.getObject({
  id: objectId,
  options: { showDisplay: true },
});
const display = obj.data?.display?.data; // name, description, image_url など
```

**主要画面**
- `/`：出品一覧（検索・並び替え・ネットワーク切替）
- `/my`：自分の Kiosk / 出品管理
- モーダル：購入フロー（ウォレット署名 → 成否表示）

**イベント駆動設計**
- `ItemListed`：新規出品時
- `ItemPurchased`：購入完了時
- `ItemDelisted`：出品取消時

**重要な注意点**
- `ItemListed.price` と実際の決済価格（`ItemPurchased.price`）は一致しない場合があります（PurchaseCap の最低価格など）
- UI 表示や集計では `ItemPurchased` イベントの価格を信頼してください

**購入フローの実装例**
```typescript
import { KioskClient, KioskTransaction } from '@mysten/kiosk';

const kioskClient = new KioskClient({ client });
const tx = new KioskTransaction({ kioskClient });

await tx.purchaseAndResolve({
  itemId,
  sellerKiosk,
  price, // MIST 単位
});
// dApp Kit の signAndExecuteTransaction で送信
```
→ TransferPolicy の解決まで一括処理

### Testing Strategy

#### Move テスト
- `sui move test` による単体テスト
- testnet/devnet での統合テスト
- PTB（Programmable Transaction Block）による機能テスト

#### Frontend テスト
- コンポーネント単体テスト（必要に応じて Jest/React Testing Library）
- E2E テスト（必要に応じて Playwright）
- testnet/devnet での実機テスト

### Git Workflow

プロジェクトルートの `CLAUDE.md` および `~/.claude/CLAUDE.md` に記載された規約に従います。

**コミットメッセージ形式**
```
[type] タイトル

- `対象ファイル`
    - 変更内容1
    - 変更内容2
```

**type の種類**
- `feat`：新機能
- `fix`：バグ修正
- `docs`：ドキュメントのみの変更
- `refactor`：リファクタリング
- `test`：テストコードの追加・修正
- `other`：その他の変更

## Domain Context

### Kiosk（キオスク）

Sui の標準 NFT マーケットプレイス基盤。以下の API を提供：

**主要 API**
- `place`：NFT を Kiosk に配置
- `list`：配置済み NFT を価格付きで出品
- `place_and_list`：配置と出品を一括実行（Move 標準に含まれる）
- `purchase`：NFT を購入（TransferRequest を発行）

**イベント**
- `ItemListed`：出品時（型付きイベント：特定の `T` で絞り込み可能）
- `ItemPurchased`：購入時（実際の決済価格を含む）
- `ItemDelisted`：出品取消時

**将来の拡張性**
- 料金・手数料・独自イベントが必要になった場合、`kiosk_extension` を使用して同じ Kiosk 上にマーケットプレイス拡張を実装可能

### TransferPolicy（転送ポリシー）

型 `T` のトレード可否を制御する共有オブジェクト。`TransferPolicy<T>` が存在しない型は Kiosk で売買できません。

**初期化手順**
`sui::transfer_policy` には `new` と `default` の 2 つの作成方法があります：

```move
// 方法1: デフォルトポリシー（最もシンプル）
let (policy, policy_cap) = sui::transfer_policy::default<WorkshopNft>(publisher, ctx);
sui::transfer::public_share_object(policy);

// 方法2: カスタムポリシー（細かい制御が必要な場合）
let (policy, policy_cap) = sui::transfer_policy::new<WorkshopNft>(publisher, ctx);
// ルールを追加...
sui::transfer::public_share_object(policy);
```

→ デプロイ直後に管理者が 1 回実行し、`TransferPolicy<WorkshopNft>` を作成・共有（または凍結）することで、`WorkshopNft` を Kiosk で売買可能にします

**購入時の解決**
```move
transfer_policy::confirm_request(policy, request)
```
→ `TransferRequest<T>` を承認し、所有権移転を完了

### TransferRequest（転送リクエスト）

第三者間の NFT 取引で発行されるリクエストオブジェクト。TransferPolicy による承認が必須。

### Display 標準

NFT メタデータを標準化し、フロント表示を容易にする仕組み。

**メタデータ例**
- `name`：NFT 名
- `description`：説明
- `image_url`：画像 URL
- その他カスタムフィールド

**フロントでの取得**
```typescript
const object = await client.getObject({
  id: objectId,
  options: { showDisplay: true }
});
const display = object.data?.display?.data;
```

## Important Constraints

### 技術的制約

1. **TransferPolicy の初期化が必須**
   - デプロイ後に管理者が `init_transfer_policy` を 1 回実行
   - `TransferPolicy<T>` を作成して共有（あるいは凍結）することで、型 `T` が Kiosk で売買可能になります
   - この処理を行わない型は Kiosk で取引できません

2. **ネットワーク対応**
   - testnet/devnet/mainnet のいずれでも動作
   - dApp Kit でネットワーク切替機能を提供

3. **価格単位**
   - 内部計算：MIST（1 SUI = 1,000,000,000 MIST）
   - UI 表示：SUI 単位

### セキュリティ要件

1. **ネットワーク/アドレス不一致検知**
   - ウォレットとアプリのネットワーク一致を確認
   - 不一致時はメッセージ表示

2. **トランザクション失敗時のリカバリ**
   - スピナー／トーストで取引中ステータスを可視化
   - 失敗時は再実行リンク・トランザクションハッシュを表示

3. **UX 考慮**
   - ローディング状態の明示
   - エラーメッセージの分かりやすい表示
   - トランザクション追跡の透明性

## External Dependencies

### Sui RPC

- **JSON-RPC**（推奨）：`queryEvents`（サーバー側メソッド名は `suix_queryEvents`）、`subscribeEvent`（WebSocket）
  - 本プロジェクトでは JSON-RPC を既定路線とします
- **GraphQL（Beta/Experimental）**（オプション）：Events クエリ
  - **注意**: GraphQL は Beta/Experimental 扱いです。将来的に変更される可能性があります
  - まずは JSON-RPC での実装を推奨します

### Sui 標準ライブラリ

- **Kiosk 標準**：`0x2::kiosk`
- **TransferPolicy 標準**：`0x2::transfer_policy`
- **Display 標準**：`0x2::display`
- **Publisher**：`0x2::package`

### フロントエンド依存

- **Sui dApp Kit**：ウォレット接続、プロバイダ、RPC フック
- **@mysten/sui**：SuiClient、トランザクション構築
- **@mysten/kiosk**：KioskClient、KioskTransaction

### 参考ドキュメント

- [Kiosk 公式ドキュメント](https://docs.sui.io/standards/kiosk)
- [TransferPolicy 公式ドキュメント](https://docs.sui.io/standards/kiosk/transfer-policy)
- [Sui TypeScript SDK](https://sdk.mystenlabs.com/typescript)
- [dApp Kit ドキュメント](https://sdk.mystenlabs.com/dapp-kit)
