module nft::nft {
    use std::string;
    use sui::display;
    use sui::event;
    use sui::package;

    const E_EMPTY_NAME: u64 = 1;
    const E_EMPTY_IMAGE: u64 = 2;

    /// Display 初期化時に Publisher を請求するためのワンタイムウィットネス。
    public struct NFT has drop {}

    /// ワークショップ用のシンプルな NFT 構造体。
    public struct WorkshopNFT has key, store {
        id: sui::object::UID,
        name: string::String,
        description: string::String,
        image_url: string::String,
        creator: address,
    }

    public struct MintEvent has copy, drop {
        object_id: sui::object::ID,
        owner: address,
        name: string::String,
        image_url: string::String,
    }

    /// ウォレットの送信者に NFT をミントするエントリポイント。
    public entry fun mint(
        name: string::String,
        description: string::String,
        image_url: string::String,
        ctx: &mut sui::tx_context::TxContext,
    ) {
        let sender = sui::tx_context::sender(ctx);
        let (nft, event) = mint_internal(sender, name, description, image_url, ctx);
        event::emit(event);
        sui::transfer::transfer(nft, sender);
    }

    fun mint_internal(
        sender: address,
        name: string::String,
        description: string::String,
        image_url: string::String,
        ctx: &mut sui::tx_context::TxContext,
    ): (WorkshopNFT, MintEvent) {
        assert!(!string::is_empty(&name), E_EMPTY_NAME);
        assert!(!string::is_empty(&image_url), E_EMPTY_IMAGE);

        let nft = WorkshopNFT {
            id: sui::object::new(ctx),
            name,
            description,
            image_url,
            creator: sender,
        };
        let event = MintEvent {
            object_id: sui::object::uid_to_inner(&nft.id),
            owner: sender,
            name: copy nft.name,
            image_url: copy nft.image_url,
        };
        (nft, event)
    }

    public fun metadata(nft: &WorkshopNFT): (string::String, string::String, string::String) {
        (copy nft.name, copy nft.description, copy nft.image_url)
    }

    public fun creator(nft: &WorkshopNFT): address {
        nft.creator
    }

    /// パッケージ publish 時に Display オブジェクトを作成・共有する。
    #[ext(init)]
    fun init(witness: NFT, ctx: &mut sui::tx_context::TxContext) {
        let publisher = package::claim(witness, ctx);
        let mut display_obj = display::new_with_fields<WorkshopNFT>(
            &publisher,
            vector[
                string::utf8(b"name"),
                string::utf8(b"description"),
                string::utf8(b"image_url"),
                string::utf8(b"link")
            ],
            vector[
                string::utf8(b"{name}"),
                string::utf8(b"{description}"),
                string::utf8(b"{image_url}"),
                string::utf8(b"{image_url}")
            ],
            ctx,
        );

        display::update_version(&mut display_obj);
        sui::transfer::public_share_object(display_obj);
        sui::transfer::public_transfer(publisher, sui::tx_context::sender(ctx));
    }
}
