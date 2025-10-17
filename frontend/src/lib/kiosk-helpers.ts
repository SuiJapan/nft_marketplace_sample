/**
 * Kiosk操作のヘルパー関数
 */

import { KioskClient, KioskTransaction, Network } from "@mysten/kiosk";
import type { SuiClient } from "@mysten/sui/client";
import type { Transaction } from "@mysten/sui/transactions";
import type { KioskInfo } from "@/types";
import {
    getDefaultItemType,
    MODULE_NAME,
    PACKAGE_ID,
    SUI_NETWORK,
} from "./constants";

/**
 * KioskClientのインスタンスを取得
 */
export function getKioskClient(client: SuiClient): KioskClient {
    const network =
        SUI_NETWORK === "mainnet" ? Network.MAINNET : Network.TESTNET;
    return new KioskClient({
        client,
        network,
    });
}

/**
 * ユーザーの既存Kioskを検索
 */
export async function findUserKiosk(
    client: SuiClient,
    address: string,
): Promise<KioskInfo | null> {
    const kioskClient = getKioskClient(client);

    try {
        const { kioskOwnerCaps } = await kioskClient.getOwnedKiosks({
            address,
        });

        if (kioskOwnerCaps.length > 0) {
            const firstKiosk = kioskOwnerCaps[0];
            return {
                kioskId: firstKiosk.kioskId,
                capId: firstKiosk.objectId,
            };
        }

        return null;
    } catch (error) {
        console.error("Error finding user kiosk:", error);
        return null;
    }
}

/**
 * 新しいKioskを作成
 */
export function createKioskTransaction(tx: Transaction, sender: string): void {
    // Kiosk を新規作成 → 共有化 → Cap を sender へ転送
    // 注意: 実際の Sui 標準APIは SDK でラップされることが多い。ここでは PTB での最低限の流れを記述。
    const [kiosk, kioskOwnerCap] = tx.moveCall({
        target: "0x2::kiosk::new",
        arguments: [],
    });
    tx.moveCall({
        target: "0x2::transfer::public_share_object",
        arguments: [kiosk],
        typeArguments: ["0x2::kiosk::Kiosk"],
    });
    tx.transferObjects([kioskOwnerCap], sender);
}

/**
 * NFTをMint（ウォレットに発行）
 * コントラクトの entry fun mint を呼び出す
 */
export function mintNFT(
    tx: Transaction,
    name: string,
    description: string,
    imageUrl: string,
): void {
    tx.moveCall({
        target: `${PACKAGE_ID}::${MODULE_NAME}::mint`,
        arguments: [
            tx.pure.string(name),
            tx.pure.string(description),
            tx.pure.string(imageUrl),
        ],
    });
}

/**
 * NFTを出品（place and list）
 */
export function listNFT(
    client: SuiClient,
    tx: Transaction,
    _kioskId: string,
    itemId: string,
    price: bigint,
    itemType?: string,
): void {
    const kioskClient = getKioskClient(client);
    const kioskTx = new KioskTransaction({ transaction: tx, kioskClient });
    kioskTx.placeAndList({
        itemType: itemType || getDefaultItemType(),
        item: tx.object(itemId),
        price: price.toString(),
    });
}

/**
 * NFTを購入（purchase and resolve）
 */
export function purchaseNFT(
    client: SuiClient,
    tx: Transaction,
    kioskId: string,
    itemId: string,
    price: bigint,
    itemType: string,
): void {
    const kioskClient = getKioskClient(client);
    const kioskTx = new KioskTransaction({ transaction: tx, kioskClient });
    kioskTx.purchaseAndResolve({
        itemType,
        itemId,
        price: price.toString(),
        sellerKiosk: kioskId,
    });
}

/**
 * 出品を取り下げ（delist）
 */
export function delistNFT(
    client: SuiClient,
    tx: Transaction,
    _kioskId: string,
    itemId: string,
    itemType?: string,
): void {
    const kioskClient = getKioskClient(client);
    const kioskTx = new KioskTransaction({ transaction: tx, kioskClient });
    kioskTx.delist({
        itemType: itemType || getDefaultItemType(),
        itemId,
    });
}
