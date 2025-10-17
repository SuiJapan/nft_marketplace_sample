/// モジュール: workshop_nft
///
/// このモジュールは、Sui NFTマーケットプレイスワークショップ向けの包括的なNFT実装を提供します。
/// 以下の重要なSui Moveの概念を示しています：
///
/// ## コア機能
/// - WorkshopNft: 表示メタデータとタイムスタンプを持つNFT構造体
/// - Mint関数: Clock統合による新しいNFTの作成
/// - Kiosk統合: マーケットプレイスでのNFT販売リスト機能
/// - TransferPolicy: 安全なNFT取引を可能にする
///
/// ## 高度なSui Moveの概念（ワークショップの焦点）
///
/// ### 1. Clock統合
/// - `sui::clock::Clock`を使用してNFT作成タイムスタンプを記録
/// - スマートコントラクトでの時間ベース機能を実演
/// - ユースケース: タイムスタンプ、期間限定機能、オークション
///
/// ### 2. Dynamic Fields（`sui::dynamic_field`）
/// - 実行時にオブジェクトに任意のデータを追加
/// - 格納される値は`store`アビリティのみが必要
/// - ラップされたデータ - 外部IDからは直接アクセス不可
/// - ユースケース: 拡張可能なメタデータ、ゲーム属性、動的プロパティ
///
/// ### 3. Dynamic Object Fields（`sui::dynamic_object_field`）
/// - NFTに他のSuiオブジェクトを添付
/// - 格納されるオブジェクトは`key` + `store`アビリティが必要
/// - オブジェクトはIDによって独立してアクセス可能なまま
/// - ユースケース: コンポーザブルNFT、装備システム、ネストされたオブジェクト
///
/// ## ワークショップの学習パス
/// 1. Clockを使用した基本的なNFTミンティング
/// 2. Dynamic Fieldメタデータ（レアリティ、レベル）の追加
/// 3. Dynamic Object Fieldアクセサリー（装備）の添付
/// 4. フル機能NFTでのすべての機能の組み合わせ
///
module contract::workshop_nft;

use std::string::{Self as string, String};
use sui::clock::Clock;
use sui::display;
use sui::dynamic_field as df;
use sui::dynamic_object_field as dof;
use sui::kiosk::{Kiosk, KioskOwnerCap};
use sui::package;
use sui::package::Publisher;
use sui::transfer::{public_share_object, public_transfer};
use sui::transfer_policy;

// ===== Error Codes =====

/// Error: Empty string provided for name, description, or url
const EEmptyString: u64 = 1;

/// Error: Invalid price (must be greater than 0)
const EInvalidPrice: u64 = 2;

// ===== Structs =====

/// One-Time-Witness for the module
public struct WORKSHOP_NFT has drop {}

/// Metadata: Dynamic field data for NFT attributes
/// This struct demonstrates Dynamic Field usage - can be added to any NFT dynamically
/// - rarity: Rarity level (1=Common, 2=Rare, 3=Epic, 4=Legendary)
/// - level: Item level (used in game mechanics)
public struct Metadata has store {
    rarity: u8,
    level: u64,
}

/// Accessory: A separate object that can be attached to NFTs
/// This struct demonstrates Dynamic Object Field usage - remains independently accessible
/// - id: Unique identifier (required for Dynamic Object Field)
/// - accessory_type: Type of accessory (e.g., "hat", "weapon", "shield")
/// - bonus_value: Numeric bonus provided by this accessory
public struct Accessory has key, store {
    id: UID,
    accessory_type: String,
    bonus_value: u64,
}

/// WorkshopNft: A simple NFT with metadata
/// - id: Unique identifier for the NFT object
/// - name: Display name of the NFT
/// - description: Description of the NFT
/// - url: Image URL for the NFT
/// - created_at: Timestamp when the NFT was created (milliseconds since Unix Epoch)
public struct WorkshopNft has key, store {
    id: UID,
    name: String,
    description: String,
    url: String,
    created_at: u64,
}

// ===== Module Initialization =====

/// Initialize the module
/// - Create and configure Display<WorkshopNft> for frontend metadata display
/// - Transfer Publisher to the deployer
#[allow(lint(share_owned))]
fun init(otw: WORKSHOP_NFT, ctx: &mut TxContext) {
    // Claim the Publisher object
    let publisher = package::claim(otw, ctx);

    // Create Display object for WorkshopNft with fields
    let keys = vector[
        string::utf8(b"name"),
        string::utf8(b"description"),
        string::utf8(b"image_url"),
    ];
    let values = vector[
        string::utf8(b"{name}"),
        string::utf8(b"{description}"),
        string::utf8(b"{url}"),
    ];
    let mut display = display::new_with_fields<WorkshopNft>(&publisher, keys, values, ctx);
    // Move 2024 method syntax: call functions from the same module as the receiver's type
    display.update_version();
    public_share_object(display);

    // Transfer Publisher back to the deployer
    public_transfer(publisher, ctx.sender());
}

// ===== Core NFT Functions =====

/// Create a new WorkshopNft (core logic)
///
/// Parameters:
/// - name: NFT name (must not be empty)
/// - description: NFT description (must not be empty)
/// - url: NFT image URL (must not be empty)
/// - clock: Clock object to get current timestamp
/// - ctx: Transaction context
///
/// Returns: WorkshopNft object
///
/// Aborts if: Any string parameter is empty
public(package) fun mint_nft(
    name: String,
    description: String,
    url: String,
    clock: &Clock,
    ctx: &mut TxContext,
): WorkshopNft {
    // Validate inputs
    assert!(!name.is_empty(), EEmptyString);
    assert!(!description.is_empty(), EEmptyString);
    assert!(!url.is_empty(), EEmptyString);

    // Get current timestamp from Clock
    let created_at = clock.timestamp_ms();

    // Create and return the NFT
    WorkshopNft {
        id: object::new(ctx),
        name,
        description,
        url,
        created_at,
    }
}

/// Mint a new WorkshopNft (entry function)
///
/// This is a thin wrapper around mint_nft that transfers the NFT to the caller.
///
/// Parameters:
/// - name: NFT name (must not be empty)
/// - description: NFT description (must not be empty)
/// - url: NFT image URL (must not be empty)
/// - clock: Clock object to get current timestamp
/// - ctx: Transaction context
///
/// Aborts if: Any string parameter is empty
entry fun mint(
    name: String,
    description: String,
    url: String,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let nft = mint_nft(name, description, url, clock, ctx);
    public_transfer(nft, ctx.sender());
}

/// Initialize TransferPolicy<WorkshopNft> (entry function)
///
/// Parameters:
/// - publisher: Publisher object for the package
/// - ctx: Transaction context
///
/// Aborts if: Transfer policy already exists or caller is unauthorized
#[allow(lint(share_owned))]
entry fun init_transfer_policy(
    publisher: Publisher,
    ctx: &mut TxContext,
) {
    let (policy, cap) = transfer_policy::new<WorkshopNft>(&publisher, ctx);
    public_share_object(policy);
    public_transfer(cap, ctx.sender());
    public_transfer(publisher, ctx.sender());
}

// ===== Kiosk Integration Functions =====

/// Place NFT in Kiosk and list it for sale (core logic)
///
/// Parameters:
/// - kiosk: Mutable reference to the Kiosk
/// - kiosk_cap: Reference to the KioskOwnerCap
/// - nft: The WorkshopNft to place and list
/// - price: Listing price in MIST (1 SUI = 1,000,000,000 MIST)
///
/// Aborts if: Price is 0 or negative
public(package) fun place_and_list_core(
    kiosk: &mut Kiosk,
    kiosk_cap: &KioskOwnerCap,
    nft: WorkshopNft,
    price: u64,
) {
    // Validate price
    assert!(price > 0, EInvalidPrice);

    // Place the NFT in the Kiosk and list it for sale
    // Method syntax on Kiosk since the function is defined in the same module as the receiver type
    kiosk.place_and_list(kiosk_cap, nft, price);
}

/// Mint a new WorkshopNft and immediately list it in Kiosk (entry function)
///
/// This is a convenience function that combines minting and listing in one transaction.
///
/// Parameters:
/// - kiosk: Mutable reference to the Kiosk
/// - kiosk_cap: Reference to the KioskOwnerCap
/// - name: NFT name (must not be empty)
/// - description: NFT description (must not be empty)
/// - url: NFT image URL (must not be empty)
/// - price: Listing price in MIST (must be > 0)
/// - clock: Clock object to get current timestamp
/// - ctx: Transaction context
///
/// Aborts if: Any validation fails
entry fun mint_and_list(
    kiosk: &mut Kiosk,
    kiosk_cap: &KioskOwnerCap,
    name: String,
    description: String,
    url: String,
    price: u64,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    // Mint the NFT
    let nft = mint_nft(name, description, url, clock, ctx);

    // Place and list in Kiosk
    place_and_list_core(kiosk, kiosk_cap, nft, price);
}

// ===== Dynamic Field Functions =====
// Dynamic fields allow adding arbitrary data to objects at runtime.
// The stored value only needs the `store` ability.

/// Add metadata to an NFT using Dynamic Field
///
/// This demonstrates how to attach additional data to an NFT after creation.
/// Dynamic fields are useful for extending objects without modifying their struct definition.
///
/// Parameters:
/// - nft: Mutable reference to the NFT
/// - rarity: Rarity level (1=Common, 2=Rare, 3=Epic, 4=Legendary)
/// - level: Item level
///
/// Note: The NFT "wraps" the metadata - it cannot be accessed by ID externally
entry fun add_metadata(
    nft: &mut WorkshopNft,
    rarity: u8,
    level: u64,
) {
    let metadata = Metadata { rarity, level };
    df::add(&mut nft.id, b"metadata", metadata);
}

/// Get metadata from an NFT
///
/// Parameters:
/// - nft: Reference to the NFT
///
/// Returns: (rarity, level) tuple
///
/// Aborts if: Metadata does not exist
public fun get_metadata(nft: &WorkshopNft): (u8, u64) {
    let metadata = df::borrow<vector<u8>, Metadata>(&nft.id, b"metadata");
    (metadata.rarity, metadata.level)
}

/// Update metadata of an NFT
///
/// Parameters:
/// - nft: Mutable reference to the NFT
/// - new_level: New level value
///
/// Aborts if: Metadata does not exist
entry fun update_metadata_level(
    nft: &mut WorkshopNft,
    new_level: u64,
) {
    let metadata = df::borrow_mut<vector<u8>, Metadata>(&mut nft.id, b"metadata");
    metadata.level = new_level;
}

/// Check if an NFT has metadata
///
/// Parameters:
/// - nft: Reference to the NFT
///
/// Returns: true if metadata exists
public fun has_metadata(nft: &WorkshopNft): bool {
    df::exists_<vector<u8>>(&nft.id, b"metadata")
}

/// Remove metadata from an NFT
///
/// Parameters:
/// - nft: Mutable reference to the NFT
///
/// Returns: The removed Metadata
///
/// Aborts if: Metadata does not exist
public fun remove_metadata(nft: &mut WorkshopNft): Metadata {
    df::remove<vector<u8>, Metadata>(&mut nft.id, b"metadata")
}

// ===== Dynamic Object Field Functions =====
// Dynamic object fields store other Sui objects (with `key` + `store` abilities).
// Unlike regular dynamic fields, these objects remain accessible via their own ID.

/// Create a new Accessory object
///
/// Parameters:
/// - accessory_type: Type name (e.g., "hat", "weapon")
/// - bonus_value: Numeric bonus value
/// - ctx: Transaction context
///
/// Returns: Accessory object
public fun create_accessory(
    accessory_type: String,
    bonus_value: u64,
    ctx: &mut TxContext,
): Accessory {
    Accessory {
        id: object::new(ctx),
        accessory_type,
        bonus_value,
    }
}

/// Attach an Accessory to an NFT using Dynamic Object Field
///
/// This demonstrates how to attach separate objects to an NFT.
/// The accessory remains accessible via its own ID even when attached.
///
/// Parameters:
/// - nft: Mutable reference to the NFT
/// - accessory: The Accessory object to attach
/// - slot_name: Name of the accessory slot (e.g., "head", "weapon")
entry fun attach_accessory(
    nft: &mut WorkshopNft,
    accessory: Accessory,
    slot_name: vector<u8>,
) {
    dof::add(&mut nft.id, slot_name, accessory);
}

/// Borrow an attached Accessory (read-only)
///
/// Parameters:
/// - nft: Reference to the NFT
/// - slot_name: Name of the accessory slot
///
/// Returns: Reference to the Accessory
///
/// Aborts if: Accessory does not exist in the slot
public fun borrow_accessory(
    nft: &WorkshopNft,
    slot_name: vector<u8>,
): &Accessory {
    dof::borrow<vector<u8>, Accessory>(&nft.id, slot_name)
}

/// Borrow an attached Accessory (mutable)
///
/// Parameters:
/// - nft: Mutable reference to the NFT
/// - slot_name: Name of the accessory slot
///
/// Returns: Mutable reference to the Accessory
///
/// Aborts if: Accessory does not exist in the slot
public fun borrow_accessory_mut(
    nft: &mut WorkshopNft,
    slot_name: vector<u8>,
): &mut Accessory {
    dof::borrow_mut<vector<u8>, Accessory>(&mut nft.id, slot_name)
}

/// Check if an NFT has an accessory in a specific slot
///
/// Parameters:
/// - nft: Reference to the NFT
/// - slot_name: Name of the accessory slot
///
/// Returns: true if accessory exists
public fun has_accessory(
    nft: &WorkshopNft,
    slot_name: vector<u8>,
): bool {
    dof::exists_<vector<u8>>(&nft.id, slot_name)
}

/// Detach an Accessory from an NFT
///
/// Parameters:
/// - nft: Mutable reference to the NFT
/// - slot_name: Name of the accessory slot
///
/// Returns: The detached Accessory object
///
/// Aborts if: Accessory does not exist in the slot
public fun detach_accessory(
    nft: &mut WorkshopNft,
    slot_name: vector<u8>,
): Accessory {
    dof::remove<vector<u8>, Accessory>(&mut nft.id, slot_name)
}

/// Entry function to detach and transfer accessory to sender
///
/// Parameters:
/// - nft: Mutable reference to the NFT
/// - slot_name: Name of the accessory slot
/// - ctx: Transaction context
entry fun detach_and_transfer_accessory(
    nft: &mut WorkshopNft,
    slot_name: vector<u8>,
    ctx: &TxContext,
) {
    let accessory = detach_accessory(nft, slot_name);
    public_transfer(accessory, ctx.sender());
}

// ===== Integrated Workshop Demo Functions =====

/// Comprehensive demo: Create an NFT with all features
///
/// This function demonstrates Clock, Dynamic Field, and Dynamic Object Field in action.
/// It creates a fully-featured NFT with timestamp, metadata, and an attached accessory.
///
/// Parameters:
/// - name: NFT name
/// - description: NFT description
/// - url: NFT image URL
/// - rarity: Rarity level (1-4)
/// - level: Initial level
/// - accessory_type: Type of accessory to attach
/// - bonus_value: Accessory bonus value
/// - clock: Clock object for timestamp
/// - ctx: Transaction context
entry fun mint_full_featured_nft(
    name: String,
    description: String,
    url: String,
    rarity: u8,
    level: u64,
    accessory_type: String,
    bonus_value: u64,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    // 1. Create NFT with Clock timestamp
    let mut nft = mint_nft(name, description, url, clock, ctx);

    // 2. Add metadata using Dynamic Field
    let metadata = Metadata { rarity, level };
    df::add(&mut nft.id, b"metadata", metadata);

    // 3. Create and attach accessory using Dynamic Object Field
    let accessory = Accessory {
        id: object::new(ctx),
        accessory_type,
        bonus_value,
    };
    dof::add(&mut nft.id, b"main_accessory", accessory);

    // 4. Transfer the fully-featured NFT to the sender
    public_transfer(nft, ctx.sender());
}

/// Get the creation timestamp of an NFT
///
/// Parameters:
/// - nft: Reference to the NFT
///
/// Returns: Creation timestamp in milliseconds
public fun get_created_at(nft: &WorkshopNft): u64 {
    nft.created_at
}

// ===== Test-Only Functions =====

#[test_only]
/// Create a WORKSHOP_NFT for testing
public fun test_init(ctx: &mut TxContext) {
    init(WORKSHOP_NFT {}, ctx);
}
