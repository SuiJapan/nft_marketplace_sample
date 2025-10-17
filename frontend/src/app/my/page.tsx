"use client";

/**
 * Kiosk管理ページ
 */

import { useEffect, useState } from "react";
import {
    useCurrentAccount,
    useSuiClient,
    useSignAndExecuteTransaction,
} from "@mysten/dapp-kit";
import { Transaction } from "@mysten/sui/transactions";
import { Header } from "@/components/header";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { NFTCard } from "@/components/nft-card";
import { MintModal } from "@/components/mint-modal";
import { ListModal } from "@/components/list-modal";
import {
    findUserKiosk,
    createKioskTransaction,
    delistNFT,
} from "@/lib/kiosk-helpers";
import { shortenAddress } from "@/lib/utils";
import { getTxUrl } from "@/lib/constants";
import { toast } from "sonner";
import { Loader2, Plus } from "lucide-react";
import type { KioskInfo, MyNFT } from "@/types";

export default function MyKioskPage() {
    const account = useCurrentAccount();
    const suiClient = useSuiClient();
    const { mutate: signAndExecute } = useSignAndExecuteTransaction();

    const [kioskInfo, setKioskInfo] = useState<KioskInfo | null>(null);
    const [loading, setLoading] = useState(true);
    const [myNFTs, setMyNFTs] = useState<MyNFT[]>([]);
    const [mintModalOpen, setMintModalOpen] = useState(false);
    const [listModalOpen, setListModalOpen] = useState(false);
    const [selectedNFT, setSelectedNFT] = useState<MyNFT | null>(null);
    const [delistingId, setDelistingId] = useState<string | null>(null);

    // Kiosk情報を取得
    useEffect(() => {
        if (!account?.address) {
            setLoading(false);
            return;
        }

        const loadKiosk = async () => {
            setLoading(true);
            try {
                const kiosk = await findUserKiosk(suiClient, account.address);
                setKioskInfo(kiosk);
            } catch (error) {
                console.error("Error loading kiosk:", error);
                toast.error("Failed to load kiosk information");
            } finally {
                setLoading(false);
            }
        };

        loadKiosk();
    }, [account, suiClient]);

    // Kiosk作成
    const handleCreateKiosk = () => {
        if (!account?.address) return;

        const tx = new Transaction();
        createKioskTransaction(tx, account.address);

        signAndExecute(
            {
                transaction: tx,
            },
            {
                onSuccess: async (result) => {
                    toast.success("Kiosk created successfully!", {
                        description: (
                            <a
                                href={getTxUrl(result.digest)}
                                target="_blank"
                                rel="noopener noreferrer"
                                className="underline"
                            >
                                View transaction
                            </a>
                        ),
                    });

                    // Kioskを再取得
                    setTimeout(async () => {
                        const kiosk = await findUserKiosk(
                            suiClient,
                            account.address,
                        );
                        setKioskInfo(kiosk);
                    }, 2000);
                },
                onError: (error) => {
                    console.error("Create kiosk error:", error);
                    toast.error("Failed to create kiosk", {
                        description: error.message,
                    });
                },
            },
        );
    };

    // NFTを取り下げ
    const handleDelist = (nft: MyNFT) => {
        if (!kioskInfo) return;

        setDelistingId(nft.objectId);

        const tx = new Transaction();
        delistNFT(tx, kioskInfo.kioskId, kioskInfo.capId, nft.objectId);

        signAndExecute(
            {
                transaction: tx,
            },
            {
                onSuccess: (result) => {
                    toast.success("NFT delisted successfully!", {
                        description: (
                            <a
                                href={getTxUrl(result.digest)}
                                target="_blank"
                                rel="noopener noreferrer"
                                className="underline"
                            >
                                View transaction
                            </a>
                        ),
                    });
                    setDelistingId(null);
                    // TODO: NFT一覧を再取得
                },
                onError: (error) => {
                    console.error("Delist error:", error);
                    toast.error("Failed to delist NFT", {
                        description: error.message,
                    });
                    setDelistingId(null);
                },
            },
        );
    };

    // ウォレット未接続
    if (!account) {
        return (
            <>
                <Header />
                <main className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-8">
                    <Card>
                        <CardContent className="pt-6">
                            <p className="text-center text-muted-foreground">
                                Please connect your wallet to manage your Kiosk
                            </p>
                        </CardContent>
                    </Card>
                </main>
            </>
        );
    }

    // Kiosk未所持
    if (!loading && !kioskInfo) {
        return (
            <>
                <Header />
                <main className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-8">
                    <Card>
                        <CardContent className="pt-6 text-center space-y-4">
                            <h2 className="text-2xl font-bold">
                                No Kiosk Found
                            </h2>
                            <p className="text-muted-foreground">
                                You need to create a Kiosk to manage your NFTs
                            </p>
                            <Button onClick={handleCreateKiosk} size="lg">
                                Create Kiosk
                            </Button>
                        </CardContent>
                    </Card>
                </main>
            </>
        );
    }

    // ローディング中
    if (loading) {
        return (
            <>
                <Header />
                <main className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-8">
                    <div className="flex items-center justify-center py-12">
                        <Loader2 className="h-8 w-8 animate-spin" />
                    </div>
                </main>
            </>
        );
    }

    const unlistedNFTs = myNFTs.filter((nft) => !nft.isListed);
    const listedNFTs = myNFTs.filter((nft) => nft.isListed);

    return (
        <>
            <Header />
            <main className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-8">
                <div className="space-y-8">
                    {/* Kiosk情報 */}
                    <Card>
                        <CardHeader>
                            <CardTitle>My Kiosk</CardTitle>
                        </CardHeader>
                        <CardContent className="space-y-2">
                            <div>
                                <span className="text-sm text-muted-foreground">
                                    Kiosk ID:
                                </span>
                                <p className="font-mono text-sm">
                                    {shortenAddress(
                                        kioskInfo?.kioskId || "",
                                        8,
                                    )}
                                </p>
                            </div>
                            <div>
                                <span className="text-sm text-muted-foreground">
                                    Cap ID:
                                </span>
                                <p className="font-mono text-sm">
                                    {shortenAddress(kioskInfo?.capId || "", 8)}
                                </p>
                            </div>
                        </CardContent>
                    </Card>

                    {/* Mint NFT */}
                    <div>
                        <Button
                            onClick={() => setMintModalOpen(true)}
                            size="lg"
                        >
                            <Plus className="mr-2 h-4 w-4" />
                            Mint New NFT
                        </Button>
                    </div>

                    {/* My NFTs (Not Listed) */}
                    <div>
                        <h2 className="text-2xl font-bold mb-4">
                            My NFTs (Not Listed)
                        </h2>
                        {unlistedNFTs.length === 0 ? (
                            <Card>
                                <CardContent className="pt-6">
                                    <p className="text-center text-muted-foreground">
                                        No NFTs yet. Mint your first NFT!
                                    </p>
                                </CardContent>
                            </Card>
                        ) : (
                            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                                {unlistedNFTs.map((nft) => (
                                    <NFTCard
                                        key={nft.objectId}
                                        objectId={nft.objectId}
                                        display={nft.display}
                                        showExplorerLink
                                        actionButton={
                                            <Button
                                                className="w-full"
                                                onClick={() => {
                                                    setSelectedNFT(nft);
                                                    setListModalOpen(true);
                                                }}
                                            >
                                                List for Sale
                                            </Button>
                                        }
                                    />
                                ))}
                            </div>
                        )}
                    </div>

                    {/* Listed NFTs */}
                    <div>
                        <h2 className="text-2xl font-bold mb-4">Listed NFTs</h2>
                        {listedNFTs.length === 0 ? (
                            <Card>
                                <CardContent className="pt-6">
                                    <p className="text-center text-muted-foreground">
                                        No listed NFTs
                                    </p>
                                </CardContent>
                            </Card>
                        ) : (
                            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                                {listedNFTs.map((nft) => (
                                    <NFTCard
                                        key={nft.objectId}
                                        objectId={nft.objectId}
                                        display={nft.display}
                                        price={nft.price}
                                        showExplorerLink
                                        actionButton={
                                            <Button
                                                className="w-full"
                                                variant="destructive"
                                                onClick={() =>
                                                    handleDelist(nft)
                                                }
                                                disabled={
                                                    delistingId === nft.objectId
                                                }
                                            >
                                                {delistingId ===
                                                    nft.objectId && (
                                                    <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                                                )}
                                                Delist
                                            </Button>
                                        }
                                    />
                                ))}
                            </div>
                        )}
                    </div>
                </div>
            </main>

            {/* Modals */}
            {kioskInfo && (
                <>
                    <MintModal
                        open={mintModalOpen}
                        onOpenChange={setMintModalOpen}
                        kioskId={kioskInfo.kioskId}
                        capId={kioskInfo.capId}
                        onSuccess={() => {
                            // TODO: NFT一覧を再取得
                        }}
                    />

                    {selectedNFT && (
                        <ListModal
                            open={listModalOpen}
                            onOpenChange={setListModalOpen}
                            kioskId={kioskInfo.kioskId}
                            capId={kioskInfo.capId}
                            itemId={selectedNFT.objectId}
                            display={selectedNFT.display}
                            onSuccess={() => {
                                // TODO: NFT一覧を再取得
                            }}
                        />
                    )}
                </>
            )}
        </>
    );
}
