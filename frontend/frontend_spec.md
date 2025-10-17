# 要件定義（フロントエンド：Next.js / frontend/）

## 目的
- Kiosk 作成（未所持ウォレットでもワンクリック）。
- NFT を mint し、ユーザーの Kiosk に入れる（コントラクトの entry を呼ぶ）。
- 任意価格で出品（list）できる。
- 一覧から購入（purchase → TransferPolicy の自動解決）できる。
- 自分の出品を取り下げ（delist）できる。
- UI は shadcn/ui を用いたモダンデザイン（ダークモード対応）。

## 技術スタック
- Next.js 14（App Router）/ React 18 / TypeScript / Node 20+
- UI：shadcn/ui + Tailwind CSS（アクセシビリティ、レスポンシブ、ダークモード）
- Sui dApp Kit（ウォレット接続、ネットワーク切替、クエリ用フック）
- @mysten/sui（SuiClient：queryEvents, getObject(showDisplay) など）
- @mysten/kiosk（KioskClient / KioskTransaction：create, placeAndList, purchaseAndResolve, delist）

## ディレクトリ例
- frontend/app（App Router 画面。/ と /my）
- frontend/components/ui（shadcn コンポーネント）
- frontend/components/kiosk（カード、モーダル、トーストなど）
- frontend/lib/sui/client.ts（SuiClient 初期化、getFullnodeUrl）
- frontend/lib/sui/kiosk.ts（KioskClient / KioskTransaction ユーティリティ）
- frontend/lib/format.ts（MIST ↔ SUI 変換、bigint ユーティリティ）
- frontend/app/api/listings（任意：ItemListed の取得 API）

## 画面要件
- /（出品一覧・検索・並び替え・購入モーダル）
- /my（自分の Kiosk / 出品管理：Mint→place、List、Delist）
- 共通 UI：スケルトン（初回ローディング）、スピナー（実行中）、トースト（成功/失敗）

## デザイン（shadcn）
- Card / Button / Input / Dialog / Select / Tabs / Badge / Skeleton / Toast / Pagination を活用。
- ダークモード（class strategy）。配色トークンは Tailwind で設定。
- 受け入れ基準：モバイル〜デスクトップで崩れない、CLS/LCP を阻害しない。

## Sui SDK の使い方（要点）
- プロバイダ
  SuiClientProvider と WalletProvider をルートに配置。createNetworkConfig と getFullnodeUrl で testnet/mainnet を切替。
- イベント取得（一覧）
  SuiClient.queryEvents で MoveEventType = 0x2::kiosk::ItemListed<PACKAGE::workshop_nft::WorkshopNft> を降順でページング取得。重複は txDigest + itemId で抑止。
  可能なら suix_subscribeEvent で購読し、失敗時はポーリングにフォールバック。
- オブジェクト表示メタ
  SuiClient.getObject({ showDisplay: true }) の display.data を利用（name, image_url など）。
- 取引の署名・実行
  dApp Kit のフックでアカウント取得と signAndExecuteTransaction を利用。署名中表示と Tx ハッシュの表示を行う。
- Kiosk SDK の高レベル API
  KioskClient.getOwnedKiosks で既存 Kiosk/Cap を探索。未所持なら同一トランザクションで KioskTransaction.create → shareAndTransferCap。
  出品は KioskTransaction.placeAndList（価格は MIST）。購入は KioskTransaction.purchaseAndResolve（内部で purchase と TransferPolicy の confirm を自動実行）。取り下げは KioskTransaction.delist。
  実行直前に在庫と価格を再確認して二重販売や価格更新を検知。

## ユースケース別フロー
- Kiosk 作成
  既存探索 → なければ create → shareAndTransferCap を同一トランザクションで実施。
- Mint → Kiosk に格納
  コントラクトの entry mint_and_place(kiosk, cap, ...) を呼ぶ（ID入力は不要。SDK が自動探索／新規作成可能）。
- 出品（list）
  placeAndList で価格（MIST）を設定。成功後は ItemListed を反映。
- 購入（purchase）
  purchaseAndResolve で TransferPolicy を自動解決。成功後は ItemPurchased を反映。
- 取り下げ（delist）
  delist 実行。成功後は ItemDelisted を反映。

## 同期・データ整合性
- 一覧は ItemListed のイベント駆動で構築しつつ、購入直前にはチェーン状態を再照合。
- WS が不安定な場合は queryEvents のポーリングで継続。

## バリデーション / UX
- 価格 > 0、name/description/url の非空と URL 形式チェック。
- ネットワーク不一致の警告。二重クリック防止。失敗時の詳細メッセージ（不足残高 / 既に購入済み / 未出品 など）と Tx リンク表示。
- 価格表示は SUI、内部は MIST（1 SUI = 10^9 MIST）。

## 環境変数
- NEXT_PUBLIC_SUI_NETWORK（既定 testnet）
- NEXT_PUBLIC_PACKAGE_ID（Move パッケージ ID）
- 任意：NEXT_PUBLIC_POLICY_ID（拡張で直接参照する場合）

## 受け入れ基準（E2E）
- Kiosk 未所持の新規ウォレットで、Mint→place→List→Purchase→Delist まで UI 操作で成功。
- 一覧はページングとリアルタイム反映（WS が落ちてもポーリング継続）。
- ダーク／ライト両テーマで視認性が確保される。
