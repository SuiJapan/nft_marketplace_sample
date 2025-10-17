/**
 * 環境変数と定数の管理
 */

import type { NetworkType } from "@/types";

// 環境変数の取得
export const SUI_NETWORK = (process.env.NEXT_PUBLIC_SUI_NETWORK ||
    "testnet") as NetworkType;
export const PACKAGE_ID =
    process.env.NEXT_PUBLIC_PACKAGE_ID ||
    "0x0000000000000000000000000000000000000000000000000000000000000000";
export const POLICY_ID = process.env.NEXT_PUBLIC_POLICY_ID;
export const MODULE_NAME = process.env.NEXT_PUBLIC_TYPE_MOD || "workshop_nft";
export const STRUCT_NAME = process.env.NEXT_PUBLIC_TYPE_STRUCT || "WorkshopNft";
const allowedPublishersRaw = process.env.NEXT_PUBLIC_ALLOWED_PUBLISHERS || "";
export const ALLOWED_PUBLISHERS = allowedPublishersRaw
    .split(",")
    .map((value) => value.trim())
    .filter((value) => value.length > 0)
    .map((value) => (value.startsWith("0x") ? value : `0x${value}`))
    .map((value) => value.toLowerCase());

// MIST / SUI 変換定数
export const MIST_PER_SUI = 1_000_000_000n;

// ページネーション設定
export const ITEMS_PER_PAGE = 20;

// ポーリング間隔（ミリ秒）
export const POLLING_INTERVAL = 10000; // 10秒

// Sui エクスプローラーURL
export const EXPLORER_URL: Record<NetworkType, string> = {
    mainnet: "https://suiscan.xyz/mainnet",
    testnet: "https://suiscan.xyz/testnet",
    devnet: "https://suiscan.xyz/devnet",
    localnet: "http://localhost:9000",
};

/**
 * トランザクションのエクスプローラーURLを取得
 */
export function getTxUrl(digest: string): string {
    return `${EXPLORER_URL[SUI_NETWORK]}/tx/${digest}`;
}

/**
 * オブジェクトのエクスプローラーURLを取得
 */
export function getObjectUrl(objectId: string): string {
    return `${EXPLORER_URL[SUI_NETWORK]}/object/${objectId}`;
}

const PACKAGE_REGEX = /^0x[a-fA-F0-9]{64}$/;

export function isValidPackageId(id: string): boolean {
    if (!PACKAGE_REGEX.test(id)) return false;
    return !/^0x0+$/.test(id.toLowerCase());
}

export const HAS_KNOWN_PACKAGE = isValidPackageId(PACKAGE_ID);

export function getDefaultItemType(): string {
    return `${PACKAGE_ID}::${MODULE_NAME}::${STRUCT_NAME}`;
}
