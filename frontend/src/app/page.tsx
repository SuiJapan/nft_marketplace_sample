"use client";

/**
 * 出品一覧ページ（ホーム）
 */

import { useSuiClient } from "@mysten/dapp-kit";
import { Loader2 } from "lucide-react";
import { useEffect, useState } from "react";
import { Header } from "@/components/header";
import { NFTCard } from "@/components/nft-card";
import { PurchaseModal } from "@/components/purchase-modal";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import {
    fetchActiveListings,
    startPollingListings,
    subscribeActiveListings,
} from "@/lib/market-events";
import type { ListedNFT } from "@/types";

export default function Home() {
    const [listings, setListings] = useState<ListedNFT[]>([]);
    const [loading, setLoading] = useState(true);
    const [selectedNFT, setSelectedNFT] = useState<ListedNFT | null>(null);
    const [purchaseModalOpen, setPurchaseModalOpen] = useState(false);
    const suiClient = useSuiClient();

    // イベント集約に基づく出品一覧の取得 + リアルタイム購読 + ポーリング
    useEffect(() => {
        let unsubscribe: (() => void) | null = null;
        let stopPolling: (() => void) | null = null;

        const load = async () => {
            setLoading(true);
            try {
                const data = await fetchActiveListings(suiClient);
                setListings(data);
            } catch (error) {
                console.error("Error loading listings:", error);
            } finally {
                setLoading(false);
            }
        };

        load();

        // リアルタイム購読（イベント受信で再読込）
        try {
            unsubscribe = subscribeActiveListings(suiClient, load);
        } catch {
            unsubscribe = null;
        }

        // フォールバックのポーリング
        stopPolling = startPollingListings(suiClient, load);

        return () => {
            unsubscribe?.();
            stopPolling?.();
        };
    }, [suiClient]);

    const handlePurchaseClick = (nft: ListedNFT) => {
        setSelectedNFT(nft);
        setPurchaseModalOpen(true);
    };

    return (
        <>
            <Header />
            <main className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-8">
                <div className="space-y-6">
                    <div>
                        <h1 className="text-3xl font-bold">NFT Marketplace</h1>
                        <p className="text-muted-foreground mt-2">
                            Browse and purchase NFTs from the marketplace
                        </p>
                    </div>

                    {loading ? (
                        <div className="flex items-center justify-center py-12">
                            <Loader2 className="h-8 w-8 animate-spin" />
                        </div>
                    ) : listings.length === 0 ? (
                        <Card>
                            <CardContent className="pt-6">
                                <p className="text-center text-muted-foreground">
                                    No NFTs listed yet. Be the first to list an
                                    NFT!
                                </p>
                            </CardContent>
                        </Card>
                    ) : (
                        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
                            {listings.map((nft) => (
                                <NFTCard
                                    key={nft.itemId}
                                    objectId={nft.itemId}
                                    display={nft.display}
                                    price={nft.price}
                                    actionButton={
                                        <Button
                                            className="w-full"
                                            onClick={() =>
                                                handlePurchaseClick(nft)
                                            }
                                        >
                                            Purchase
                                        </Button>
                                    }
                                />
                            ))}
                        </div>
                    )}
                </div>
            </main>

            <PurchaseModal
                open={purchaseModalOpen}
                onOpenChange={setPurchaseModalOpen}
                nft={selectedNFT}
                onSuccess={() => {
                    // 購入成功後、一覧から削除
                    setListings((prev) =>
                        prev.filter(
                            (nft) => nft.itemId !== selectedNFT?.itemId,
                        ),
                    );
                }}
            />
        </>
    );
}
