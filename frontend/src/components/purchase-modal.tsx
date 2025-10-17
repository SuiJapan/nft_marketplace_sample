"use client";

/**
 * NFT購入モーダル
 */

import { useSignAndExecuteTransaction, useSuiClient } from "@mysten/dapp-kit";
import { Transaction } from "@mysten/sui/transactions";
import { Loader2 } from "lucide-react";
import Image from "next/image";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import {
    Dialog,
    DialogContent,
    DialogDescription,
    DialogFooter,
    DialogHeader,
    DialogTitle,
} from "@/components/ui/dialog";
import { getTxUrl } from "@/lib/constants";
import { purchaseNFT } from "@/lib/kiosk-helpers";
import { formatNumber, mistToSui } from "@/lib/utils";
import type { ListedNFT } from "@/types";

interface PurchaseModalProps {
    open: boolean;
    onOpenChange: (open: boolean) => void;
    nft: ListedNFT | null;
    onSuccess?: () => void;
}

export function PurchaseModal({
    open,
    onOpenChange,
    nft,
    onSuccess,
}: PurchaseModalProps) {
    const { mutate: signAndExecute, isPending } =
        useSignAndExecuteTransaction();
    const suiClient = useSuiClient();

    if (!nft) return null;

    const handlePurchase = () => {
        const priceBigInt = BigInt(nft.price);
        const tx = new Transaction();
        purchaseNFT(
            suiClient,
            tx,
            nft.kioskId,
            nft.itemId,
            priceBigInt,
            nft.itemType,
        );

        signAndExecute(
            {
                transaction: tx,
            },
            {
                onSuccess: (result) => {
                    toast.success("NFT purchased successfully!", {
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
                    onOpenChange(false);
                    onSuccess?.();
                },
                onError: (error) => {
                    console.error("Purchase error:", error);
                    toast.error("Failed to purchase NFT", {
                        description: error.message,
                    });
                },
            },
        );
    };

    return (
        <Dialog open={open} onOpenChange={onOpenChange}>
            <DialogContent>
                <DialogHeader>
                    <DialogTitle>Purchase NFT</DialogTitle>
                    <DialogDescription>
                        Confirm your purchase of this NFT
                    </DialogDescription>
                </DialogHeader>

                <div className="space-y-4">
                    {/* NFT Preview */}
                    <div className="relative aspect-square w-full overflow-hidden rounded-lg bg-muted">
                        <Image
                            src={nft.display.image_url}
                            alt={nft.display.name}
                            fill
                            className="object-cover"
                        />
                    </div>

                    <div>
                        <h3 className="font-semibold text-lg">
                            {nft.display.name}
                        </h3>
                        <p className="text-sm text-muted-foreground mt-1">
                            {nft.display.description}
                        </p>
                    </div>

                    <div className="rounded-lg border p-4 space-y-2">
                        <div className="flex justify-between">
                            <span className="text-muted-foreground">
                                Price:
                            </span>
                            <span className="font-bold text-lg">
                                {formatNumber(mistToSui(nft.price))} SUI
                            </span>
                        </div>
                        <div className="flex justify-between text-sm">
                            <span className="text-muted-foreground">
                                In MIST:
                            </span>
                            <span className="font-mono">
                                {formatNumber(nft.price)}
                            </span>
                        </div>
                    </div>

                    <p className="text-sm text-muted-foreground">
                        This transaction will transfer the NFT to your wallet
                        and automatically resolve the transfer policy.
                    </p>
                </div>

                <DialogFooter>
                    <Button
                        variant="outline"
                        onClick={() => onOpenChange(false)}
                    >
                        Cancel
                    </Button>
                    <Button onClick={handlePurchase} disabled={isPending}>
                        {isPending && (
                            <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                        )}
                        Confirm Purchase
                    </Button>
                </DialogFooter>
            </DialogContent>
        </Dialog>
    );
}
