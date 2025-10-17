"use client";

/**
 * Sui Client とプロバイダの設定
 */

import { createNetworkConfig } from "@mysten/dapp-kit";
import { getFullnodeUrl } from "@mysten/sui/client";
import { SUI_NETWORK } from "./constants";

// ネットワーク設定
const { networkConfig, useNetworkVariable } = createNetworkConfig({
    localnet: { url: getFullnodeUrl("localnet") },
    devnet: { url: getFullnodeUrl("devnet") },
    testnet: { url: getFullnodeUrl("testnet") },
    mainnet: { url: getFullnodeUrl("mainnet") },
});

export { networkConfig, useNetworkVariable };

// デフォルトネットワーク
export const defaultNetwork = SUI_NETWORK;
