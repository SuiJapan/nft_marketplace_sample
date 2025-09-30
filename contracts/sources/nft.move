module nft::nft {
    // ハンズオン教材向けの NFT モジュール。
    // Move で最小限のミント処理と Display 初期化を提供し、フロントエンドからの `move_call`
    // を通じて Testnet 上で NFT を体験できるようにする。
    use std::string;
    use sui::display;
    use sui::event;
    use sui::package;

    // 入力バリデーション用のエラーコード。
    const E_EMPTY_NAME: u64 = 1;
    const E_EMPTY_IMAGE: u64 = 2;

    // Display 初期化時に Publisher を請求するためのワンタイムウィットネス。
    public struct NFT has drop {}

    // ミントされる WorkshopNFT の本体。`key` を持つためオンチェーンに保存され、
    // `image_url` フィールドを Display から参照してサムネイルを表示できる。
    public struct WorkshopNFT has key, store {
        id: sui::object::UID,
        name: string::String,
        description: string::String,
        image_url: string::String,
        creator: address,
    }

    // ミント処理で発行されるイベント。フロントでトランザクション結果を追跡しやすくするため、
    // オブジェクト ID や入力値をそのまま記録している。
    public struct MintEvent has copy, drop {
        object_id: sui::object::ID,
        owner: address,
        name: string::String,
        image_url: string::String,
    }

    // ウォレットの送信者に NFT をミントするエントリポイント。
    // `@mysten/dapp-kit` から `move_call` される想定で、入力の空文字チェックのみを行う。
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

    // 実際のミント処理本体。イベント生成と返却値をまとめて扱いたいため、
    // エントリポイントとは切り分けている。
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

    // フロントから mint 結果を読み取る用途の単純なゲッター。
    public fun metadata(nft: &WorkshopNFT): (string::String, string::String, string::String) {
        (copy nft.name, copy nft.description, copy nft.image_url)
    }

    // 作成者（ミント時の送信者）を返すヘルパー。
    public fun creator(nft: &WorkshopNFT): address {
        nft.creator
    }

    // パッケージ publish 時に Display オブジェクトを作成・共有する初期化ロジック。
    // `#[ext(init)]` により publish トランザクション内で自動実行され、Explorer での
    // 画像表示に必要なフィールドテンプレートを登録する。
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
