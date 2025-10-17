"use client";

/**
 * NFT出品モーダル
 */

import { useSignAndExecuteTransaction, useSuiClient } from "@mysten/dapp-kit";
import { Transaction } from "@mysten/sui/transactions";
import { Loader2 } from "lucide-react";
import { useState } from "react";
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
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { getTxUrl } from "@/lib/constants";
import { listNFT } from "@/lib/kiosk-helpers";
import { formatNumber, suiToMist } from "@/lib/utils";
import type { NFTDisplay } from "@/types";

interface ListModalProps {
    open: boolean;
    onOpenChange: (open: boolean) => void;
    kioskId: string;
    itemId: string;
    display: NFTDisplay;
    onSuccess?: () => void;
}

export function ListModal({
    open,
    onOpenChange,
    kioskId,
    itemId,
    display,
    onSuccess,
}: ListModalProps) {
    const { mutate: signAndExecute, isPending } =
        useSignAndExecuteTransaction();
    const suiClient = useSuiClient();
    const [price, setPrice] = useState("");
    const [error, setError] = useState("");

    const validate = () => {
        const priceNum = Number.parseFloat(price);

        if (!price || Number.isNaN(priceNum)) {
            setError("Price is required and must be a number");
            return false;
        }

        if (priceNum <= 0) {
            setError("Price must be greater than 0");
            return false;
        }

        if (priceNum > 1000000) {
            setError("Price must be less than 1,000,000 SUI");
            return false;
        }

        setError("");
        return true;
    };

    const handleList = () => {
        if (!validate()) return;

        const priceMist = suiToMist(price);
        const tx = new Transaction();
        listNFT(suiClient, tx, kioskId, itemId, priceMist);

        signAndExecute(
            {
                transaction: tx,
            },
            {
                onSuccess: (result) => {
                    toast.success("NFT listed successfully!", {
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
                    setPrice("");
                    onOpenChange(false);
                    onSuccess?.();
                },
                onError: (error) => {
                    console.error("List error:", error);
                    toast.error("Failed to list NFT", {
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
                    <DialogTitle>List NFT for Sale</DialogTitle>
                    <DialogDescription>
                        Set a price and list your NFT on the marketplace
                    </DialogDescription>
                </DialogHeader>

                <div className="space-y-4">
                    {/* NFT Preview */}
                    <div className="rounded-lg border p-4">
                        <h4 className="font-semibold mb-2">{display.name}</h4>
                        <p className="text-sm text-muted-foreground">
                            {display.description}
                        </p>
                    </div>

                    {/* Price Input */}
                    <div>
                        <Label htmlFor="price">Price (SUI)</Label>
                        <Input
                            id="price"
                            type="number"
                            step="0.000000001"
                            min="0"
                            value={price}
                            onChange={(e) => setPrice(e.target.value)}
                            placeholder="0.1"
                        />
                        {error && (
                            <p className="text-sm text-destructive mt-1">
                                {error}
                            </p>
                        )}
                        {price && !error && (
                            <p className="text-sm text-muted-foreground mt-1">
                                = {formatNumber(suiToMist(price).toString())}{" "}
                                MIST
                            </p>
                        )}
                    </div>
                </div>

                <DialogFooter>
                    <Button
                        variant="outline"
                        onClick={() => onOpenChange(false)}
                    >
                        Cancel
                    </Button>
                    <Button onClick={handleList} disabled={isPending}>
                        {isPending && (
                            <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                        )}
                        List for Sale
                    </Button>
                </DialogFooter>
            </DialogContent>
        </Dialog>
    );
}
