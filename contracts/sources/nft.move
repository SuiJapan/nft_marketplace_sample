module nft::nft {
    // ハンズオン教材向けの NFT モジュール（最新版記法）。
    use std::string;
    use sui::display;
    use sui::event;
    use sui::package;
    use sui::transfer;
    use sui::object;
    use sui::tx_context;

    // 入力バリデーション用のエラーコード。
    const E_EMPTY_NAME: u64 = 1;
    const E_EMPTY_IMAGE: u64 = 2;

    // Display 初期化時の Publisher 請求に使うワンタイムウィットネス。
    public struct NFT has drop {}

    // ミントされる NFT 本体。
    public struct WorkshopNFT has key, store {
        id: object::UID,
        name: string::String,
        description: string::String,
        image_url: string::String,
        creator: address,
    }

    // ミントイベント。
    public struct MintEvent has copy, drop {
        object_id: object::ID,
        owner: address,
        name: string::String,
        image_url: string::String,
    }

    // ウォレット送信者に NFT をミントするエントリポイント（PTB専用）。
    entry fun mint(
        name: string::String,
        description: string::String,
        image_url: string::String,
        ctx: &mut tx_context::TxContext,
    ) {
        let sender = tx_context::sender(ctx);
        let (nft, mint_evt) = mint_internal(sender, name, description, image_url, ctx);
        event::emit(mint_evt);
        // オブジェクトに store 能力があるのでどこからでも転送可能
        transfer::public_transfer(nft, sender);
    }

    // 実際のミント処理。
    fun mint_internal(
        sender: address,
        name: string::String,
        description: string::String,
        image_url: string::String,
        ctx: &mut tx_context::TxContext,
    ): (WorkshopNFT, MintEvent) {
        assert!(!string::is_empty(&name), E_EMPTY_NAME);
        assert!(!string::is_empty(&image_url), E_EMPTY_IMAGE);

        let nft = WorkshopNFT {
            id: object::new(ctx),
            name,
            description,
            image_url,
            creator: sender,
        };
        let evt = MintEvent {
            // 最新のメソッド構文でIDを取得
            object_id: nft.id.to_inner(),
            owner: sender,
            name: copy nft.name,
            image_url: copy nft.image_url,
        };
        (nft, evt)
    }

    // メタデータ取得。
    public fun metadata(nft: &WorkshopNFT): (string::String, string::String, string::String) {
        (copy nft.name, copy nft.description, copy nft.image_url)
    }

    // 作成者（ミント時の送信者）。
    public fun creator(nft: &WorkshopNFT): address {
        nft.creator
    }

    // パッケージ publish 時に Display を作成・共有する初期化ロジック。
    // Suiのinitializerは `fun init(...)` をモジュール内に定義するだけでOK（属性は不要）。
    fun init(witness: NFT, ctx: &mut tx_context::TxContext) {
        // Publisher を取得
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

        display::update_version(&mut disp);
        transfer::public_share_object(disp);

        // Publisher を発行者へ返す（保有しておきたいケースが多い）
        transfer::public_transfer(publisher, tx_context::sender(ctx));
    }
}
