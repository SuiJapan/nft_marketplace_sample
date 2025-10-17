/**
 * NFT マーケットプレイスの型定義
 */

export interface NFTDisplay {
    name: string;
    description: string;
    image_url: string;
}

export interface ListedNFT {
    itemId: string;
    kioskId: string;
    price: string; // MIST単位（bigint文字列）
    display: NFTDisplay;
    owner: string;
    txDigest: string;
    itemType: string;
    packageId: string;
    moduleName: string;
    structName: string;
}

export interface MyNFT {
    objectId: string;
    kioskId: string;
    display: NFTDisplay;
    isListed: boolean;
    price?: string; // 出品中の場合のみ
    itemType?: string;
    packageId?: string;
    moduleName?: string;
    structName?: string;
}

export interface KioskInfo {
    kioskId: string;
    capId: string;
}

export type NetworkType = "mainnet" | "testnet" | "devnet" | "localnet";
