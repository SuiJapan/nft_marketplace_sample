import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";
import { MIST_PER_SUI } from "./constants";

export function cn(...inputs: ClassValue[]) {
    return twMerge(clsx(inputs));
}

/**
 * MISTをSUIに変換
 */
export function mistToSui(mist: bigint | string): string {
    const mistBigInt = typeof mist === "string" ? BigInt(mist) : mist;
    const sui = Number(mistBigInt) / Number(MIST_PER_SUI);
    return sui.toFixed(9).replace(/\.?0+$/, "");
}

/**
 * SUIをMISTに変換
 */
export function suiToMist(sui: number | string): bigint {
    const suiNumber = typeof sui === "string" ? Number.parseFloat(sui) : sui;
    return BigInt(Math.round(suiNumber * Number(MIST_PER_SUI)));
}

/**
 * アドレスを短縮表示
 */
export function shortenAddress(address: string, chars = 4): string {
    if (!address) return "";
    return `${address.slice(0, chars + 2)}...${address.slice(-chars)}`;
}

/**
 * 数値をカンマ区切りでフォーマット
 */
export function formatNumber(value: number | string): string {
    const num = typeof value === "string" ? Number.parseFloat(value) : value;
    return new Intl.NumberFormat("en-US").format(num);
}
