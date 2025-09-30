# ハンズオン概要

目的

* 参加者が Sui Testnet 上でシンプルな NFT をミントできる最小 dApp を体験し、パッケージの公開〜検証〜フロントからの呼び出しまでを一通り学ぶ。

対象者・前提

* Web フロントの基本（React の props/state など）を知っている初学者〜中級者。
* ブロックチェーン/NFT は初学者でも可。

ゴール（到達目標）

* Sui CLI を使って Move パッケージを Testnet に publish できる。
* Sui Vision で公開したパッケージ／モジュール／関数を確認できる。
* dApp Kit を使ってウォレット接続し、フロントから `move_call` でミント処理を実行できる。
* ミントしたオブジェクト（NFT）をエクスプローラで確認できる。

制約

* ネットワーク：Testnet 固定。
* ウォレット：Sui Wallet など dApp Kit 対応ウォレット（主催側で推奨を案内）。
* 既存テンプレート：`react-e2e-counter` をベースに最小改造（UI は簡素）。

# システム構成（概要）

構成要素

* Move パッケージ：`nft` モジュール（主催側で事前用意／教材リポジトリに同梱）。
* フロントエンド：React + Vite（`@mysten/dapp-kit` 利用）。
* RPC：Sui 提供の testnet RPC（dApp Kit の `createNetworkConfig` 使用）。
* エクスプローラ：Sui Vision（主に確認用）。
* **実行環境：GitHub Codespaces（`.devcontainer`により Sui CLI / Node / Git / Move拡張を自動セットアップ）**。

データフロー（ハイレベル）

1. 参加者または主催者アカウントで Move パッケージを publish。
2. Package ID を控える。
3. フロントの `.env` に Package ID／モジュール・関数名を設定。
4. ウォレット接続 → 入力フォームからメタデータ送信 → `transaction` を作成 → `move_call` 実行。
5. 戻り値のオブジェクト ID をエクスプローラで確認。

# 技術スタック

* 言語：Move（on-chain）, TypeScript/React（off-chain）。
* ランタイム/ツール：Sui CLI, dApp Kit, Vite, pnpm（npm でも可）。
* Lint/Format（任意）：ESLint, Prettier。

# リポジトリ構成（提案）

```
/ (root)
  /contracts
    Move.toml
    /sources
      nft.move
    /tests
      nft_tests.move
  /app
    .env.example
    index.html
    /src
      main.tsx
      App.tsx
      components/
        ConnectPanel.tsx
        MintForm.tsx
        ResultCard.tsx
        ExplorerLinks.tsx
      lib/
        network.ts
        sui.ts (tx builder ヘルパ)
  /docs
    HANDSON_GUIDE.md
```

# 事前準備（主催側）

* 教材 GitHub リポジトリを用意（上記構成）。
* **`.devcontainer/` を `sui_codespace_starter` からコピー**し、Codespaces 起動時に Sui CLI/Node が自動導入されるようにする（`setup.sh` / `update-on-start.sh` を含む）。
* Move モジュール（`nft.move`）はビルド済みでコミット。
* 動作確認用に主催者が Testnet へ publish 済みの Package ID を 1 つ用意（当日デモ用）。
* 参加者が自分で publish する手順も資料化（回線・時間に応じて切替可）。
* 代替 Faucet（公式が混雑する場合）や Package ID のバックアッププランを用意。
* 会場の Wi‑Fi, 電源, 事前インストール案内（**ウォレット拡張のみ**）。

# 事前準備（参加者）

* **ローカル準備は原則不要（ブラウザのみ）**。
* 必要なもの：

  * GitHub アカウント（Free で可）
  * Web ブラウザ（Chrome 推奨）
  * **Sui 対応ウォレット拡張**（Sui Wallet など）※署名用にのみ使用。Testnet 追加＆FaucetでSUI取得。
* *任意*：GitHub の **Codespaces 無料枠**の把握と節約のための「停止」操作に慣れておく。

# ワークショップ進行（90 分想定）

1. オリエンテーション（5 分）

   * 目的・流れ・最終ゴールの共有。
2. Move/パッケージの最小概念（10 分）

   * `struct` と `object::UID`、公開関数と `transfer` の概要。
3. CLI で publish（15–20 分）

   * ビルド → publish → Package ID 確認 → Sui Vision で検証。
4. dApp Kit でウォレット接続（10 分）

   * Connect ボタンでアカウント取得・ネットワーク確認。
5. フロントからミント（20–25 分）

   * `.env` へ Package ID/モジュール名/関数名を設定 → 入力 → 実行 → 結果確認。
6. エクスプローラでオブジェクト確認（10 分）

   * 発行トランザクション・オブジェクトの所有者・フィールド表示を確認。
7. まとめ・拡張課題（5–10 分）

   * Kiosk, Display, 画像ホスティング, 動的メタデータなど。

# Move コントラクト仕様（最小）

モジュール名

* `nft`（パッケージ内に 1 モジュール）

公開構造体

* `struct Nft has key, store { id: UID, name: String, description: String, image_url: String }`

公開関数

* `public entry fun mint(recipient: address, name: String, description: String, image_url: String)`

  * 新規 `Nft` オブジェクトを作成し `transfer::public_transfer` で `recipient` に送付。
  * 戻り値なし（トランザクションの Effects でオブジェクト ID を確認）。

バリデーション

* `name`/`image_url` は空文字禁止（`abort` コード定義）。

テスト（任意）

* `sui move test` で mint の正常系・異常系を 2–3 ケース用意。

# Codespaces を使った配布・起動フロー（推奨）

参加者向け手順（ブラウザのみ）

1. 教材リポジトリを開き、**Code → Codespaces → Create codespace on main** をクリック。
2. ブラウザ版 VS Code が開き、自動セットアップが走る（完了を待つ）。
3. ターミナルで確認：

```
sui --version
node -v
git --version
```

4. `sui client` を初回実行し、ウォレット（keystore）と環境を初期化：

```
sui client
# プロンプトに従い、Testnet を選択または URL 入力→alias設定
sui client envs
sui client active-address
```

5. Faucet：

   * **Sui Wallet** の Testnet 画面から Faucet を実行 もしくは
   * 公式の Testnet Faucet（Web）を利用。
6. 教材の `/app` でフロントを起動：

```
cd app
pnpm i
pnpm dev
```

* PORTS タブに表示された 5173(想定) を **Open in Browser**。
* 表示された `https://*.github.dev` の URL は HTTPS なのでウォレット拡張と相性が良い。

7. **ウォレット接続 → フォーム入力 → Mint 実行 → 結果リンクから Sui Vision を開く。**

講師向け Tips

* Codespace の無料枠節約：アイドル時は停止／終了（UI 左下から Stop）。
* Codespace を削除すると keystore も消える。重要な鍵は `~/.sui/sui_config` をバックアップするか、**イベント用アカウント**を使う。
* 端末差のトラブルが起きにくいので“フロント重視の体験”に時間配分できる。

---

# パッケージのデプロイ手順（CLI）

前提

* `contracts` ディレクトリ直下で実施。

1. ビルド

```
sui move build
```

2. Testnet の設定と切替（未設定の場合）

```
sui client envs
sui client new-env --alias testnet --rpc https://fullnode.testnet.sui.io:443
sui client switch --env testnet
```

3. アドレスと残高確認

```
sui client addresses
sui client active-address
sui client gas
```

4. Publish

* Sui v1.24.1 以降は `--gas-budget` 省略可。混雑時は指定推奨。

```
sui client publish --path . --json
# うまくいかない場合の例：
# sui client publish --path . --gas-budget 100000000 --json
```

5. 出力の `packageId` を控える（`.env` へ転記）。

# Sui Vision での確認手順

1. Sui Vision を開く。
2. 検索欄に Package ID をペーストしパッケージページへ遷移。
3. Code/Contract タブでモジュール一覧 → `nft` モジュールの公開関数に `mint` があるか確認。
4. Transactions タブで `Publish` トランザクションのステータス確認。
5. ミント後は Objects/NFTs タブで新規オブジェクトの ID・所有者・フィールドを確認。
6. 代替エクスプローラ（Sui Explorer / Suiscan）も紹介。

# フロントエンド仕様

ページ

* `/`：ウォレット接続、入力フォーム（name / description / image_url）、実行ボタン、結果表示（tx digest / object id）

主要コンポーネント

* `ConnectPanel`：`<ConnectButton />` を表示。現在のネットワーク（Testnet）とアカウントを表示。
* `MintForm`：入力・バリデーション・送信処理。実行中のローディングとエラー表示。
* `ResultCard`：トランザクション結果とオブジェクト/トランザクションへのエクスプローラリンク。
* `ExplorerLinks`：Package/Tx/Object を Sui Vision で開くためのリンクビルダー。

ネットワーク設定（例）

* `lib/network.ts` にて dApp Kit の `createNetworkConfig` を使用し `testnet` の RPC を設定。

環境変数（`.env`）

```
VITE_SUI_NETWORK=testnet
VITE_PACKAGE_ID=0x...
VITE_MODULE=nft
VITE_FN_MINT=mint
```

トランザクション構築（概念）

* 署名・送信は dApp Kit の `useSignAndExecuteTransaction` を利用。
* `Transaction` を生成し `moveCall` で `target: `${PACKAGE_ID}::${MODULE}::${FN}` を指定。
* 引数は `pure.string(name)` などを利用し型に合わせて渡す。

**Codespaces 実行時の補足**

* Vite のポート（既定 5173）は Codespaces により自動フォワード。`Open in Browser` で `*.github.dev` が開く。
* `.env` は Codespace 上で作成/編集（`.env.example`→`.env`）。
* ウォレット拡張はローカルブラウザ側で動作し、`*.github.dev` のオリジンに対して署名連携可能。

# テスト項目（抜粋）

* フロント：未入力時バリデーション、正常ミント、エラー時の表示。
* コントラクト：空文字で `abort` すること、正常ミントで `key` オブジェクトが生成されること。
* CLI：publish 成功、`packageId` 抽出、Sui Vision 上でモジュール表示確認。

# トラブルシューティング

* Faucet がレート制限：少し待つ／代替 Faucet を試す／主催者から一時的に送付。
* `Module not found`：`.env` の Package ID / モジュール名のミス。ビルド・publish 済みか確認。
* `Insufficient gas`：Testnet SUI を補充。`--gas-budget` を上げて再実行。
* `Unknown network`：ウォレット・dApp 両方で Testnet を選択。
* トランザクションが永遠に pending：ネットワーク混雑の可能性。しばらくしてからエクスプローラで確認。

# 進行バリエーション（回線/時間による切替）

* 早回し：主催者が publish 済みの Package ID を配布し、全員フロントからミント体験に集中。
* しっかりコース：各自が publish → Package ID を自分で取得 → フロントに設定。

# 追加学習（発展）

* Display/Metadata の導入（フィールドの UI 表示整形）。
* 画像ホスティング（IPFS/Walrus など）と image_url の取り扱い。
* Kiosk での出品/譲渡。
* アップグレード（`UpgradeCap` を用いた `upgrade` ワークフロー）。

# 配布物

* 教材リポジトリ URL（contracts/app/docs）。
* スライド（流れ、主要コマンド、よくある詰まりポイント）。
* チートシート（CLI・.env・エクスプローラでの見方）。

# ライセンス・その他

* 教材は MIT または Apache-2.0（サンプルコードの再利用を許諾）。
* 注意：Testnet は随時リセットの可能性。イベント直前にも動作確認を実施。
