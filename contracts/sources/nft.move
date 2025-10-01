module nft::nft {
    // これはワークショップ（入門）向けの最小限な NFT サンプルです。
    // 目的:
    // - 「オブジェクト（object）」ベースのNFTの作り方を学ぶ
    // - エントリ関数でミントして、ウォレットに転送する流れを理解する
    // - Display(表示用メタデータ)の初期化例を見る
    // 注意: 学習用のため、権限制御や高度な検証は最小限です。

    // よく使う標準/フレームワークのモジュールを `use` して短く呼べるようにします。
    use std::string;
    use sui::display;
    use sui::package;

    // 入力バリデーション用のエラーコード。
    const E_EMPTY_NAME: u64 = 1;
    const E_EMPTY_IMAGE: u64 = 2;

    // Display 初期化時の Publisher 請求に使うワンタイムウィットネス。
    // パッケージ publish 時に自動で与えられ、`package::claim` に使います。
    public struct NFT has drop {}

    // ミントされる NFT 本体。
    // - `key` 能力: Sui台帳で「独自のIDを持つオブジェクト」であることを示します。
    // - `store` 能力: 他モジュールへ移動（転送）できるようにします。
    public struct WorkshopNFT has key, store {
        id: object::UID,          // Sui が管理するユニークID（必須）
        name: string::String,     // 表示名
        description: string::String, // 説明文
        image_url: string::String,// 画像URL（IPFSやHTTPSなど）
        creator: address,         // 作成者（ミント時の送信者）
    }

    // イベント発行は学習をシンプルにするため削除しました。
    // その代わり、ミント処理の結果はそのままウォレットに転送します。

    // ウォレット送信者に NFT をミントするエントリポイント。
    // - 受け取った `name`/`description`/`image_url` を検証してミント
    // - できあがった NFT オブジェクトを送信者へ転送
    entry fun mint(
        name: string::String,
        description: string::String,
        image_url: string::String,
        ctx: &mut tx_context::TxContext,
    ) {
        let sender = tx_context::sender(ctx);
        let nft = mint_internal(sender, name, description, image_url, ctx);
        // `store` 能力があるためどこからでも安全に転送できます。
        transfer::public_transfer(nft, sender);
    }

    // 実際のミント処理（ロジック部分）。
    // - 入力値を簡単にチェック
    // - `object::new(ctx)` で新しいオブジェクトIDを割り当て
    // - フィールドを詰めて `WorkshopNFT` を返す
    fun mint_internal(
        sender: address,
        name: string::String,
        description: string::String,
        image_url: string::String,
        ctx: &mut tx_context::TxContext,
    ): WorkshopNFT {
        // ここでは最低限のチェックだけを行います。
        assert!(!string::is_empty(&name), E_EMPTY_NAME);
        assert!(!string::is_empty(&image_url), E_EMPTY_IMAGE);

        WorkshopNFT {
            id: object::new(ctx),
            name,
            description,
            image_url,
            creator: sender,
        }
    }

    // メタデータ取得（UI表示などで便利）。
    public fun metadata(nft: &WorkshopNFT): (string::String, string::String, string::String) {
        (copy nft.name, copy nft.description, copy nft.image_url)
    }

    // 作成者（ミント時の送信者アドレス）。
    public fun creator(nft: &WorkshopNFT): address {
        nft.creator
    }

    // パッケージ publish 時に Display を作成・共有する初期化ロジック。
    // Suiのinitializerは `fun init(...)` をモジュール内に定義するだけでOK（属性は不要）。
    fun init(witness: NFT, ctx: &mut tx_context::TxContext) {
        // Publisher を取得（Display の登録に必要）
        let publisher = package::claim(witness, ctx);

        // 表示に使うフィールドテンプレートを登録
        let mut disp = display::new_with_fields<WorkshopNFT>(
            &publisher,
            vector[
                string::utf8(b"name"),
                string::utf8(b"description"),
                string::utf8(b"image_url"),
                string::utf8(b"link"),
            ],
            vector[
                string::utf8(b"{name}"),
                string::utf8(b"{description}"),
                string::utf8(b"{image_url}"),
                string::utf8(b"{image_url}"),
            ],
            ctx,
        );

        // Display のバージョンを進めて有効化し、作成者に転送
        display::update_version(&mut disp);
        transfer::public_transfer(disp, tx_context::sender(ctx));

        // Publisher を発行者へ返す（保有しておきたいケースが多い）
        transfer::public_transfer(publisher, tx_context::sender(ctx));
    }
}
