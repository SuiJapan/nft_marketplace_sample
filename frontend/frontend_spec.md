# 要件定義（フロントエンド：Next.js / `frontend/`）

## 目的
- ユーザーが GUI で次を行える：  
  ① Kiosk 作成、② NFT の mint（自分の Kiosk に入る）、③ 任意価格で出品（list）、④ 一覧から購入、⑤ 取り下げ（delist）。

## 技術スタック
- Next.js 14+（App Router）, React 18, TypeScript, Node 20+
- **Sui dApp Kit**（`SuiClientProvider`, `WalletProvider` など）:contentReference[oaicite:5]{index=5}
- **@mysten/sui**（`SuiClient` による JSON-RPC: `queryEvents`, `getObject`(showDisplay) 等）:contentReference[oaicite:6]{index=6}
- **@mysten/kiosk**（`KioskClient`, `KioskTransaction`: `create`, `placeAndList`, `purchaseAndResolve`, `delist` 等）:contentReference[oaicite:7]{index=7}

## 主要画面
- `/` 出品一覧（表示・購入）  
- `/my` 自分の Kiosk と出品管理（Mint→place, List, Delist）

## ユースケース別フロー
1) **Kiosk 作成**  
   - 既存探索: `KioskClient.getOwnedKiosks({ address })`。  
   - 無ければ作成: `KioskTransaction.create()` → `shareAndTransferCap(address)`（同一PTBで自動作成）。:contentReference[oaicite:8]{index=8}

2) **NFT を mint（Kiosk に入る）**  
   - 方式A: コントラクトの `entry mint_and_place(kiosk, cap, ...)` を呼ぶ（既存 Kiosk/Cap 利用）。  
   - 方式B: `entry mint_and_place_autocreate(...)` を直接呼ぶ（ID入手不要・毎回新規になる点に注意）。  
   - 成功後、`ItemListed` ではなく **place イベントは任意**のため、Kiosk 中身の再取得で反映。

3) **任意価格で出品（list）**  
   - `KioskTransaction.placeAndList({ itemId, kiosk, cap, price })` を使用（MIST 単位）。Kiosk 標準の `list`/`place_and_list` を底で利用。:contentReference[oaicite:9]{index=9}  
   - 成功後、`ItemListed` イベントで UI 更新。:contentReference[oaicite:10]{index=10}

4) **一覧から購入**  
   - 一覧はイベント駆動：`queryEvents` で `MoveEventType = 0x2::kiosk::ItemListed<...WorkshopNft>` を取得・ページング。:contentReference[oaicite:11]{index=11}  
   - 購入は `KioskTransaction.purchaseAndResolve({ itemId, sellerKiosk, price })` を使用（内部で `purchase` → `confirm_request` を一括）。:contentReference[oaicite:12]{index=12}  
   - 成功後、`ItemPurchased` で UI 更新。:contentReference[oaicite:13]{index=13}

5) **出品取り下げ（delist）**  
   - `KioskTransaction.delist({ itemId })`（または `kiosk::delist` 呼び出し）で取り下げ。  
   - 成功後、`ItemDelisted` で UI 更新。:contentReference[oaicite:14]{index=14}

## データ取得・同期
- 初回：`SuiClient.queryEvents` で `ItemListed<...WorkshopNft>` を降順・cursor 付きで取得。:contentReference[oaicite:15]{index=15}
- リアルタイム：`suix_subscribeEvent`（WS）で購読を試み、**不安定時はポーリングにフォールバック**（公式が推奨）。:contentReference[oaicite:16]{index=16}
- 表示メタ：`getObject({ showDisplay: true })` で Display を解決（name/image_url 等）。:contentReference[oaicite:17]{index=17}
- 価格表示：内部は **MIST (u64)**、UI は SUI に換算（1 SUI = 10^9 MIST）。

## バリデーション・UX
- 価格 > 0、ネットワーク一致（testnet 既定）、署名前の確認ダイアログ、失敗時トースト＋Tx ハッシュ表示。
- 一覧の重複排除：`ItemDelisted` / `ItemPurchased` を反映し、在庫チェックは購入直前に再クエリ。

## 環境変数
- `NEXT_PUBLIC_SUI_NETWORK`（`testnet` 既定）  
- `NEXT_PUBLIC_PACKAGE_ID`（デプロイ済み Move パッケージ ID）

## スコープ外
- オークション等の拡張 Kiosk アプリ（将来拡張）。:contentReference[oaicite:18]{index=18}
