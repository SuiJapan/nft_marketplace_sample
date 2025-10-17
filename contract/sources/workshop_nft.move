/// Module: workshop_nft
///
/// This module provides a minimal NFT implementation for the Sui NFT marketplace workshop.
/// It includes:
/// - WorkshopNft: A simple NFT structure with display metadata
/// - mint functions: Create new NFTs
/// - Kiosk integration: List NFTs for sale
/// - TransferPolicy: Enable NFT trading on Kiosk
module contract::workshop_nft;

use std::string::{Self as string, String};
use sui::display;
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

/// WorkshopNft: A simple NFT with metadata
/// - id: Unique identifier for the NFT object
/// - name: Display name of the NFT
/// - description: Description of the NFT
/// - url: Image URL for the NFT
public struct WorkshopNft has key, store {
    id: UID,
    name: String,
    description: String,
    url: String,
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
/// - ctx: Transaction context
///
/// Returns: WorkshopNft object
///
/// Aborts if: Any string parameter is empty
public(package) fun mint_nft(
    name: String,
    description: String,
    url: String,
    ctx: &mut TxContext,
): WorkshopNft {
    // Validate inputs
    assert!(!name.is_empty(), EEmptyString);
    assert!(!description.is_empty(), EEmptyString);
    assert!(!url.is_empty(), EEmptyString);

    // Create and return the NFT
    WorkshopNft {
        id: object::new(ctx),
        name,
        description,
        url,
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
/// - ctx: Transaction context
///
/// Aborts if: Any string parameter is empty
entry fun mint(
    name: String,
    description: String,
    url: String,
    ctx: &mut TxContext,
) {
    let nft = mint_nft(name, description, url, ctx);
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
    ctx: &mut TxContext,
) {
    // Mint the NFT
    let nft = mint_nft(name, description, url, ctx);

    // Place and list in Kiosk
    place_and_list_core(kiosk, kiosk_cap, nft, price);
}

// ===== Test-Only Functions =====

#[test_only]
/// Create a WORKSHOP_NFT for testing
public fun test_init(ctx: &mut TxContext) {
    init(WORKSHOP_NFT {}, ctx);
}
