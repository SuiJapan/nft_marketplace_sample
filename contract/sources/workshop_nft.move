/// Module: workshop_nft
///
/// This module provides a minimal NFT implementation for the Sui NFT marketplace workshop.
/// It includes:
/// - WorkshopNft: A simple NFT structure with display metadata
/// - mint functions: Create new NFTs
/// - Kiosk integration: List NFTs for sale
/// - TransferPolicy: Enable NFT trading on Kiosk
module contract::workshop_nft;

use std::string::String;
use sui::package;
use sui::display;
use sui::transfer_policy;
use sui::kiosk::{Kiosk, KioskOwnerCap};

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
fun init(otw: WORKSHOP_NFT, ctx: &mut TxContext) {
    // Claim the Publisher object
    let publisher = package::claim(otw, ctx);

    // Create Display object for WorkshopNft
    let mut display = display::new<WorkshopNft>(&publisher, ctx);

    // Set display fields
    display.add(b"name".to_string(), b"{name}".to_string());
    display.add(b"description".to_string(), b"{description}".to_string());
    display.add(b"image_url".to_string(), b"{url}".to_string());

    // Update and freeze the display
    display.update_version();

    // Transfer Display and Publisher to the deployer
    transfer::public_transfer(display, ctx.sender());
    transfer::public_transfer(publisher, ctx.sender());
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
    ctx: &mut TxContext
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
    ctx: &mut TxContext
) {
    let nft = mint_nft(name, description, url, ctx);
    transfer::public_transfer(nft, ctx.sender());
}

// ===== TransferPolicy Functions =====

/// Initialize TransferPolicy for WorkshopNft (entry function)
///
/// This function must be called once after deployment by the module deployer
/// to enable trading of WorkshopNft on Kiosk.
///
/// Parameters:
/// - publisher: Publisher object (proves module ownership)
/// - ctx: Transaction context
///
/// Effects:
/// - Creates a TransferPolicy<WorkshopNft> with no rules and shares it
/// - Transfers TransferPolicyCap to the caller for future policy updates
///
/// Note: The lint warning is suppressed because we create and share the policy
/// in the same transaction, which is safe and intentional.
#[allow(lint(share_owned))]
entry fun init_transfer_policy(
    publisher: &package::Publisher,
    ctx: &mut TxContext
) {
    // Create transfer policy with no rules (allows free transfers)
    let (policy, policy_cap) = transfer_policy::new<WorkshopNft>(publisher, ctx);

    // Share the policy for public use
    transfer::public_share_object(policy);

    // Transfer the policy cap to the caller for future policy updates
    transfer::public_transfer(policy_cap, ctx.sender());
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
    ctx: &mut TxContext
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
