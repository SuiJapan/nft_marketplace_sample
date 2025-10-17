# 要件定義（フロントエンド：Next.js / `frontend/`）

## 目的
- GUI で次を行える：
  ① Kiosk 作成、② NFT の mint（Kiosk に入れる）、③ 任意価格で出品（list）、
  ④ 一覧から購入、⑤ 取り下げ（delist）。
- UI は **shadcn/ui** を用い、モダンでアクセシブル、ダークモード対応。

## 技術スタック
- Next.js 14+（App Router）, React 18, TypeScript, Node 20+
- UI：**shadcn/ui + Tailwind CSS**（ダークモード／A11y／レスポンシブ）
- Sui：**@mysten/dapp-kit**, **@mysten/sui**, **@mysten/kiosk**

## ディレクトリ
```

frontend/
app/
components/
ui/                # shadcn のコンポーネント
kiosk/             # Kiosk用UI（カード/モーダル/トースト）
lib/
sui/client.ts      # SuiClient 初期化
sui/kiosk.ts       # KioskClient/KioskTransaction ユーティリティ
format.ts          # MIST<->SUI 変換, bigint utils
(api/)               # 必要なら /api/listings など（App RouterのRoute Handler）

```

## デザイン要件（shadcn / UX）
- **スタイル**：余白広め、カード型レイアウト、スケルトン/スピナーでローディング表示、トーストで結果通知。
- **主要コンポーネント**：Card, Button, Input, Dialog/Sheet, Select, Tabs, Badge, Skeleton, Toast, Pagination.
- **配色/テーマ**：ダークモード対応（`class` strategy）。ブランド色のトークン定義。
- **アクセシビリティ**：キーボード操作、ARIA属性、コントラスト確保。
- **インストール要件**：
  - Tailwind 設定済み（`tailwind.config`/`globals.css`）。
  - shadcn 初期化済み（`components.json`）＋必要なUIを `npx shadcn add card button input dialog ...` で導入。
- **受け入れ基準**：
  - 主要画面で CLS/LCP を阻害しない（Skeleton で初期レンダリング最適化）。
  - モバイル（sm）〜デスクトップ（lg）で崩れない。

## 画面
- `/` 出品一覧（検索／並び替え／購入モーダル）
- `/my` 自分の Kiosk / 出品管理（Mint→place / List / Delist）

## Sui SDK 使い方（実装メモ）
> Claude はここを参考にコード化すること。

### 1) プロバイダとネットワーク
- `SuiClientProvider` と `WalletProvider` をアプリルートに配置。
- `createNetworkConfig()` に `getFullnodeUrl('testnet' | 'mainnet')` を与え、ネットワーク切替を提供。
- 受け入れ基準：ネットワーク不一致時は警告バナー。

### 2) SuiClient（JSON-RPC）・基本クエリ
- **イベント取得**（一覧のデータソース）：
  - `client.queryEvents({ query: { MoveEventType: '0x2::kiosk::ItemListed<PACKAGE::workshop_nft::WorkshopNft>' }, order: 'descending', limit, cursor })`
  - 直近 N 件をページングで取得。重複は txDigest + itemId で排除。
- **オブジェクト表示メタ**（カード描画用）：
  - `client.getObject({ id: objectId, options: { showDisplay: true } })` → `display.data` を使用（name, image_url 等）。
- **同期戦略**：まずポーリング（`queryEvents`）、可能なら WS で `suix_subscribeEvent` を併用。WS失敗時は自動フォールバック。

### 3) dApp Kit（署名・実行）
- `useCurrentAccount()` でアドレス取得。
- `useSignAndExecuteTransaction()` or `useSignAndExecuteTransactionBlock()` で PTB を署名・実行。
- 受け入れ基準：署名ダイアログ、実行中スピナー、成功/失敗トースト、Txリンク表示。

### 4) Kiosk SDK（高レベルTxビルダー）
- `KioskClient.getOwnedKiosks({ address })` で既存の Kiosk/Cap を探索。
- 無ければ **同一PTB** で `new KioskTransaction(...).create().shareAndTransferCap(address)` により「サイレント作成」。
- **出品（place+list）**：
  - `KioskTransaction.placeAndList({ itemId, price, ... })` で MIST 価格を設定。
- **購入**：
  - `KioskTransaction.purchaseAndResolve({ itemId, sellerKiosk, price })` で、`purchase` → `TransferPolicy` の `confirm_request` まで一括。
  - 決済前に在庫/価格の再確認（`getObject` や `kioskClient.getKioskContents`）。
- **取り下げ**：
  - `KioskTransaction.delist({ itemId })`。
- 受け入れ基準：各Tx成功後に `ItemListed` / `ItemPurchased` / `ItemDelisted` を反映して一覧更新。

### 5) ミント→Kioskに入れる（コントラクト連携）
- 方式A：既存Kiosk/Cap を引数に **`entry mint_and_place(kiosk, cap, ...)`** を呼ぶ。
- 方式B：**`entry mint_and_place_autocreate(...)`** を呼び、内部で Kiosk 作成→place 済み（毎回新規Kioskになる点に注意）。
- 受け入れ基準：ミント完了後、ユーザーの Kiosk コンテンツに NFT が存在する。

### 6) 金額・ユーティリティ
- 価格は **MIST（u64, bigint）** で保持／送信。UI は SUI で表示（`1 SUI = 10^9 MIST`）。
- `formatMist(mist): string`、`toMist(sui: string): bigint` を用意し、フォーム入力は SUI 小数→MIST bigint に変換。
- 購入直前の「最終価格」と在庫を必ず再チェック。

## API（任意の最小構成）
- `/api/listings`：`queryEvents(ItemListed<WorkshopNft>)` を呼んで JSON を返す（ページング対応）。
- `/api/health`：ネットワーク疎通／RPC健全性チェック。

## バリデーション・UX
- 価格 > 0、URL 形式、name/description の非空。
- ネットワーク/アドレス不一致時の抑止、マルチクリック防止（Button disabled）。
- 失敗トーストに理由（insufficient funds / not listed / already purchased など）とTxハッシュ。

## 環境変数
- `NEXT_PUBLIC_SUI_NETWORK`（`testnet` 既定）
- `NEXT_PUBLIC_PACKAGE_ID`（Move パッケージID）
- （任意）`NEXT_PUBLIC_POLICY_ID`（参照が必要な場合）

## 受け入れ基準（E2E）
- Kioskが存在しないウォレットでも「Mint→place→List→Purchase→Delist」まで **UI操作のみ**で成功。
- 一覧のページングとリアルタイム反映（WSが落ちてもポーリング継続）。
- ダーク/ライト両テーマで視認性が確保される。