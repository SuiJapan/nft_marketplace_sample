# 要件定義（フロントエンド＋イベント受信：Next.js / frontend/）

## 更新概要（整合性の是正）
- Move コントラクトの現状（`contract/sources/workshop_nft.move`）は `mint` と `mint_and_list` を提供し、`mint_and_place` は存在しない。
- フロントの UI は「Mint（価格なし）」→「List（価格入力）」の2段階での出品を想定している。
- そのため本フロント仕様は以下の方針に統一する：
  - Mint は `entry fun mint(...)` を呼び出して NFT をウォレットに発行。
  - List は Kiosk 標準の `placeAndList`（SDK: `KioskTransaction.placeAndList`）で実施。
  - これによりコントラクト変更を伴わず、UI と整合する実装を確定する。

## 目的
- 特定パッケージで発行された NFT のみを対象に、Kiosk の出品・購入・取り下げを提供する。
- Sui のイベントを受信・集約して「有効な出品一覧」を構築する。
- ユーザーは UI から Kiosk 作成、mint、出品（list）、購入、取り下げ（delist）を行える。

## 技術スタック
- Next.js 14（App Router）／React 18／TypeScript／Node 20+
- UI：shadcn/ui + Tailwind（ダークモード・A11y）
- Sui dApp Kit（SuiClientProvider／WalletProvider、ネットワーク切替）
- @mysten/sui（SuiClient：`queryEvents`／`subscribeEvent`、`getObject(showDisplay)`）
- @mysten/kiosk（KioskClient：`getOwnedKiosks`、KioskTransaction：`placeAndList`／`purchaseAndResolve`／`delist`）

## 環境変数
- `NEXT_PUBLIC_SUI_NETWORK`: `mainnet | testnet | devnet | localnet`（既定: `testnet`）
- 単一パッケージ運用（初期構成）: `NEXT_PUBLIC_PACKAGE_ID`（対象パッケージ ID、例: `0x...`）
- 複数パッケージ横断（ワークショップ向け）:
  - `NEXT_PUBLIC_TYPE_MOD`（既定: `workshop_nft`）
  - `NEXT_PUBLIC_TYPE_STRUCT`（既定: `WorkshopNft`）
  - `NEXT_PUBLIC_ALLOWED_PUBLISHERS`（任意。許可するパッケージIDをカンマ区切りで列挙。未指定なら誰でも）
- `NEXT_PUBLIC_POLICY_ID`（任意）: 必要に応じて参照
- 備考: 単一パッケージ運用時は NFT 型 FQTN を `${PACKAGE_ID}::workshop_nft::WorkshopNft` で合成。複数パッケージ横断時は module/struct 名で判定し、package は任意。

## ディレクトリ（本リポジトリの実態に合わせて更新）
- `frontend/src/app`（`/` と `/my` 画面、App Router）
- `frontend/src/components/ui`（shadcn コンポーネント）
- `frontend/src/components/*`（ヘッダ／カード／モーダル類）
- `frontend/src/lib/sui-client.ts`（SuiClient プロバイダ設定）
- `frontend/src/lib/kiosk-helpers.ts`（Kiosk 操作ユーティリティ）
- `frontend/src/lib/utils.ts`（MIST↔SUI 変換、表示ユーティリティ）
- `frontend/src/types.ts`（型定義）
- （任意）`frontend/src/lib/market-events.ts`（イベント集約ロジック）

## 機能要件（ユーザーフロー）
- Kiosk 作成
  - 既存探索：`KioskClient.getOwnedKiosks(address)`。
  - 未所持なら `0x2::kiosk` を用いて新規作成→共有→Cap 転送（単一トランザクション）を実行。
- Mint（ウォレットに発行）
  - コントラクトの `entry fun mint(name, description, url, ctx)` を呼び出す。
  - 成功後、`/my` の「未出品」一覧に表示。
- 出品（list）
  - `KioskTransaction.placeAndList({ itemId, itemType: "${PACKAGE}::workshop_nft::WorkshopNft", price[MIST] })` を使用。
  - 成功後、`ItemListed` を取り込んで一覧を更新。
- 購入（buy）
  - `KioskTransaction.purchaseAndResolve({ itemId, sellerKiosk, price[MIST] })` を使用（TransferPolicy 解決まで一括）。
  - 成功後、`ItemPurchased` を取り込んで一覧を更新。
- 取り下げ（delist）
  - `KioskTransaction.delist({ itemId, itemType })` を実行。
  - 成功後、`ItemDelisted` を取り込んで一覧を更新。

## イベント受信・集約（マーケット基盤）
- データソース：`SuiClient.queryEvents`（履歴）＋ `subscribeEvent`（リアルタイム）。WS 不安定時はポーリングへフォールバック（既定 10 秒）。
- フィルタ条件（対象コレクションの特定）：
  - 単一パッケージ運用（厳密・低ノイズ）
    - 完全修飾型で絞り込む（例）：
      - `0x2::kiosk::ItemListed<${PACKAGE_ID}::workshop_nft::WorkshopNft>`
      - `0x2::kiosk::ItemPurchased<${PACKAGE_ID}::workshop_nft::WorkshopNft>`
      - `0x2::kiosk::ItemDelisted<${PACKAGE_ID}::workshop_nft::WorkshopNft>`
  - 複数パッケージ横断（ワークショップ向け）
    - まず `MoveEventModule = { package: '0x2', module: 'kiosk' }` で対象イベントを広く取得。
    - 各イベントの `type` の generic 内側（`0xPKG::module::Struct`）を抽出し、`module == NEXT_PUBLIC_TYPE_MOD` かつ `struct == NEXT_PUBLIC_TYPE_STRUCT` に合致するものだけ採用（package は不問）。
    - 追加で `NEXT_PUBLIC_ALLOWED_PUBLISHERS` が設定されている場合は `0xPKG` が許可リストに含まれるもののみ採用。
- 同期戦略：
  - 初回ロード：降順＋`cursor` でページング取得。
  - `ItemListed` を主キー（`itemId + kioskId`）で upsert。
  - 同一キーの `ItemPurchased`／`ItemDelisted` の存在で「無効化」し、画面には「有効な出品」のみを出す。
  - 表示直前に該当オブジェクトを `getObject({ showDisplay: true })` で再検証（存在／ロック／最新表示名など）。

### 複数パッケージ対応の高度化（任意）
- Publish イベント監視と `getNormalizedMoveModulesByPackage(packageId)` により、`workshop_nft` モジュールを持つ `packageId` を自動的に許可リストへ登録。
- 許可済み `packageId` ごとに `MoveEventType = 0x2::kiosk::ItemListed<0x{pkg}::workshop_nft::WorkshopNft>` の購読を並列化し、ノイズをさらに低減。

## Sui SDK の要点
- プロバイダ：アプリのルートを `SuiClientProvider`／`WalletProvider` でラップし、`createNetworkConfig` と `getFullnodeUrl` でネットワークを切替。
- イベント：`queryEvents` を履歴、`subscribeEvent` をリアルタイムに使用（`order`／`limit`／`cursor` 管理）。
- 表示メタ：`getObject` の `options.showDisplay = true` を指定して `display.data`（`name`／`description`／`image_url`）を利用。
- Kiosk：`KioskClient` は所有 Kiosk 取得、`KioskTransaction` は `placeAndList`／`purchaseAndResolve`／`delist` を提供（`itemType` は上記 FQTN）。

## バリデーション・UX
- 入力検証：`name`/`description`/`url` の必須・最大長、`url` は `https://` 始まり。
- 価格：内部は bigint（MIST）、UI は SUI 表示（1 SUI = 10^9 MIST）。0 より大きいことを必須。
- ネットワーク不一致検知、署名中スピナー、失敗時の詳細メッセージと Tx ハッシュ表示。
- 一覧の重複排除、ページング、検索・並び替え。WS 障害時のポーリング継続。

## 受け入れ基準（E2E）
- 新規ウォレット（Kiosk 未所持）でも UI 操作のみで「Kiosk 作成 → mint → list → purchase → delist」が成功する。
- 単一パッケージ運用では「指定 `PACKAGE_ID` の `WorkshopNft` 型」以外は一覧に出さない（MoveEventType フィルタで保証）。
- 複数パッケージ横断運用では「module=workshop_nft, struct=WorkshopNft の型」の出品が、異なる packageId でも一覧・売買対象として集約される。
- WS 切断時もポーリングで一覧が継続更新される。

## 実装上の注意（このリポジトリに対する具体化）
- `frontend/src/lib/kiosk-helpers.ts`：
  - Mint は `mint_and_place` ではなく `workshop_nft::mint` を呼ぶ実装に修正すること。
  - `KioskTransaction` の生成時は `kioskClient` を正しく渡す（`undefined as any` をやめ、`new KioskClient({ client, network })` を使用）。
- `frontend/src/app/page.tsx`：
  - 現在の実装は単一パッケージ運用を前提（`PACKAGE_ID` で MoveEventType を固定）。複数パッケージ横断へ移行する際は `MoveEventModule(0x2::kiosk)` で取得→module/struct 名でクライアント判定する実装へ切替えること（`market-events.ts` の拡張で対応）。
- `.env`：
  - `NEXT_PUBLIC_PACKAGE_ID` を必ず設定し、UI からも確認可能にする（ヘッダ等に簡易表示してもよい）。
  - 複数パッケージ横断時は `NEXT_PUBLIC_TYPE_MOD` / `NEXT_PUBLIC_TYPE_STRUCT` / `NEXT_PUBLIC_ALLOWED_PUBLISHERS` を設定。
