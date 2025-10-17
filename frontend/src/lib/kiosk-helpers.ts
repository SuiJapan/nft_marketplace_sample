/**
 * Kiosk操作のヘルパー関数
 */

import type { SuiClient } from "@mysten/sui/client";
import { Transaction } from "@mysten/sui/transactions";
import { KioskClient, KioskTransaction, Network } from "@mysten/kiosk";
import type { KioskInfo } from "@/types";
import { PACKAGE_ID, SUI_NETWORK } from "./constants";

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
    // Kioskを作成（0x2::kiosk::default）
    const [kiosk, kioskOwnerCap] = tx.moveCall({
        target: "0x2::kiosk::default",
        arguments: [],
    });

    // Kioskを共有オブジェクトにする
    tx.moveCall({
        target: "0x2::transfer::public_share_object",
        arguments: [kiosk],
        typeArguments: ["0x2::kiosk::Kiosk"],
    });

    // KioskOwnerCapをsenderに転送
    tx.transferObjects([kioskOwnerCap], sender);
}

/**
 * NFTをMintしてKioskに配置
 * コントラクトのmint_and_place関数を呼び出す
 */
export function mintAndPlaceNFT(
    tx: Transaction,
    kioskId: string,
    capId: string,
    name: string,
    description: string,
    imageUrl: string,
): void {
    tx.moveCall({
        target: `${PACKAGE_ID}::workshop_nft::mint_and_place`,
        arguments: [
            tx.object(kioskId),
            tx.object(capId),
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
    tx: Transaction,
    kioskId: string,
    capId: string,
    itemId: string,
    price: bigint,
): void {
    const kioskTx = new KioskTransaction({
        transaction: tx,
        kioskClient: undefined as any,
    });

    kioskTx.placeAndList({
        itemType: `${PACKAGE_ID}::workshop_nft::WorkshopNft`,
        item: tx.object(itemId),
        price: price.toString(),
    });
}

/**
 * NFTを購入（purchase and resolve）
 */
export function purchaseNFT(
    tx: Transaction,
    kioskId: string,
    itemId: string,
    price: bigint,
): void {
    const kioskTx = new KioskTransaction({
        transaction: tx,
        kioskClient: undefined as any,
    });

    kioskTx.purchaseAndResolve({
        itemType: `${PACKAGE_ID}::workshop_nft::WorkshopNft`,
        itemId,
        price: price.toString(),
        sellerKiosk: kioskId,
    });
}

/**
 * 出品を取り下げ（delist）
 */
export function delistNFT(
    tx: Transaction,
    kioskId: string,
    capId: string,
    itemId: string,
): void {
    const kioskTx = new KioskTransaction({
        transaction: tx,
        kioskClient: undefined as any,
    });

    kioskTx.delist({
        itemType: `${PACKAGE_ID}::workshop_nft::WorkshopNft`,
        itemId,
    });
}
