#[test_only]
module contract::workshop_nft_tests {
    use std::string;
    use sui::test_scenario::{Self as ts, Scenario};
    use sui::kiosk::{Self, Kiosk, KioskOwnerCap};
    use sui::transfer_policy::TransferPolicy;
    use sui::package;
    use contract::workshop_nft::{Self, WorkshopNft};

    // Test addresses
    const ADMIN: address = @0xAD;
    const USER1: address = @0x1;

    // ===== Helper Functions =====

    /// Initialize the module for testing
    fun init_module(scenario: &mut Scenario) {
        ts::next_tx(scenario, ADMIN);
        {
            workshop_nft::test_init(ts::ctx(scenario));
        };
    }

    // ===== Tests =====

    #[test]
    /// Test: Successfully mint an NFT
    fun test_mint_nft_success() {
        let mut scenario = ts::begin(ADMIN);
        init_module(&mut scenario);

        // Mint NFT
        ts::next_tx(&mut scenario, USER1);
        {
            workshop_nft::mint(
                string::utf8(b"Test NFT"),
                string::utf8(b"A test NFT"),
                string::utf8(b"https://example.com/nft.png"),
                ts::ctx(&mut scenario)
            );
        };

        // Verify NFT was transferred to USER1
        ts::next_tx(&mut scenario, USER1);
        {
            let nft = ts::take_from_sender<WorkshopNft>(&scenario);
            ts::return_to_sender(&scenario, nft);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = workshop_nft::EEmptyString)]
    /// Test: Fail to mint NFT with empty name
    fun test_mint_nft_empty_name() {
        let mut scenario = ts::begin(ADMIN);
        init_module(&mut scenario);

        // Try to mint NFT with empty name
        ts::next_tx(&mut scenario, USER1);
        {
            workshop_nft::mint(
                string::utf8(b""),  // Empty name
                string::utf8(b"A test NFT"),
                string::utf8(b"https://example.com/nft.png"),
                ts::ctx(&mut scenario)
            );
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = workshop_nft::EEmptyString)]
    /// Test: Fail to mint NFT with empty description
    fun test_mint_nft_empty_description() {
        let mut scenario = ts::begin(ADMIN);
        init_module(&mut scenario);

        // Try to mint NFT with empty description
        ts::next_tx(&mut scenario, USER1);
        {
            workshop_nft::mint(
                string::utf8(b"Test NFT"),
                string::utf8(b""),  // Empty description
                string::utf8(b"https://example.com/nft.png"),
                ts::ctx(&mut scenario)
            );
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = workshop_nft::EEmptyString)]
    /// Test: Fail to mint NFT with empty URL
    fun test_mint_nft_empty_url() {
        let mut scenario = ts::begin(ADMIN);
        init_module(&mut scenario);

        // Try to mint NFT with empty URL
        ts::next_tx(&mut scenario, USER1);
        {
            workshop_nft::mint(
                string::utf8(b"Test NFT"),
                string::utf8(b"A test NFT"),
                string::utf8(b""),  // Empty URL
                ts::ctx(&mut scenario)
            );
        };

        ts::end(scenario);
    }

    #[test]
    /// Test: Initialize TransferPolicy
    fun test_init_transfer_policy() {
        let mut scenario = ts::begin(ADMIN);
        init_module(&mut scenario);

        // Get Publisher
        ts::next_tx(&mut scenario, ADMIN);
        {
            let publisher = ts::take_from_sender<package::Publisher>(&scenario);

            // Initialize TransferPolicy
            workshop_nft::init_transfer_policy(&publisher, ts::ctx(&mut scenario));

            ts::return_to_sender(&scenario, publisher);
        };

        // Verify TransferPolicy was created and shared
        ts::next_tx(&mut scenario, ADMIN);
        {
            let _policy = ts::take_shared<TransferPolicy<WorkshopNft>>(&scenario);
            ts::return_shared(_policy);
        };

        ts::end(scenario);
    }

    #[test]
    /// Test: Mint and list NFT in Kiosk
    fun test_mint_and_list() {
        let mut scenario = ts::begin(ADMIN);
        init_module(&mut scenario);

        // Create Kiosk for USER1
        ts::next_tx(&mut scenario, USER1);
        {
            let (kiosk, kiosk_cap) = kiosk::new(ts::ctx(&mut scenario));
            transfer::public_share_object(kiosk);
            transfer::public_transfer(kiosk_cap, USER1);
        };

        // Mint and list NFT
        ts::next_tx(&mut scenario, USER1);
        {
            let mut kiosk = ts::take_shared<Kiosk>(&scenario);
            let kiosk_cap = ts::take_from_sender<KioskOwnerCap>(&scenario);

            workshop_nft::mint_and_list(
                &mut kiosk,
                &kiosk_cap,
                string::utf8(b"Listed NFT"),
                string::utf8(b"An NFT listed on Kiosk"),
                string::utf8(b"https://example.com/listed.png"),
                1_000_000_000,  // 1 SUI in MIST
                ts::ctx(&mut scenario)
            );

            ts::return_to_sender(&scenario, kiosk_cap);
            ts::return_shared(kiosk);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = workshop_nft::EInvalidPrice)]
    /// Test: Fail to list NFT with zero price
    fun test_mint_and_list_zero_price() {
        let mut scenario = ts::begin(ADMIN);
        init_module(&mut scenario);

        // Create Kiosk for USER1
        ts::next_tx(&mut scenario, USER1);
        {
            let (kiosk, kiosk_cap) = kiosk::new(ts::ctx(&mut scenario));
            transfer::public_share_object(kiosk);
            transfer::public_transfer(kiosk_cap, USER1);
        };

        // Try to mint and list NFT with zero price
        ts::next_tx(&mut scenario, USER1);
        {
            let mut kiosk = ts::take_shared<Kiosk>(&scenario);
            let kiosk_cap = ts::take_from_sender<KioskOwnerCap>(&scenario);

            workshop_nft::mint_and_list(
                &mut kiosk,
                &kiosk_cap,
                string::utf8(b"Listed NFT"),
                string::utf8(b"An NFT listed on Kiosk"),
                string::utf8(b"https://example.com/listed.png"),
                0,  // Invalid price
                ts::ctx(&mut scenario)
            );

            ts::return_to_sender(&scenario, kiosk_cap);
            ts::return_shared(kiosk);
        };

        ts::end(scenario);
    }
}
