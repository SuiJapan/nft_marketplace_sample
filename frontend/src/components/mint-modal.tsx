"use client";

/**
 * NFT Mint モーダル
 */

import { useSignAndExecuteTransaction } from "@mysten/dapp-kit";
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
import {
    getTxUrl,
    HAS_KNOWN_PACKAGE,
    MODULE_NAME,
    PACKAGE_ID,
} from "@/lib/constants";
import { mintNFT } from "@/lib/kiosk-helpers";
import { suiToMist } from "@/lib/utils";

interface MintModalProps {
    open: boolean;
    onOpenChange: (open: boolean) => void;
    kioskId?: string;
    capId?: string;
    onSuccess?: () => void;
}

export function MintModal({
    open,
    onOpenChange,
    kioskId,
    capId,
    onSuccess,
}: MintModalProps) {
    const { mutate: signAndExecute, isPending } =
        useSignAndExecuteTransaction();

    const [formData, setFormData] = useState({
        name: "",
        description: "",
        imageUrl: "",
        price: "",
    });

    const [errors, setErrors] = useState<Record<string, string>>({});

    const validate = () => {
        const newErrors: Record<string, string> = {};

        if (!formData.name || formData.name.length === 0) {
            newErrors.name = "Name is required";
        } else if (formData.name.length > 100) {
            newErrors.name = "Name must be less than 100 characters";
        }

        if (!formData.description || formData.description.length === 0) {
            newErrors.description = "Description is required";
        } else if (formData.description.length > 500) {
            newErrors.description =
                "Description must be less than 500 characters";
        }

        if (!formData.imageUrl || formData.imageUrl.length === 0) {
            newErrors.imageUrl = "Image URL is required";
        } else if (!formData.imageUrl.startsWith("https://")) {
            newErrors.imageUrl = "Image URL must start with https://";
        }

        const priceNum = Number.parseFloat(formData.price || "0");
        if (formData.price && (Number.isNaN(priceNum) || priceNum <= 0)) {
            newErrors.price = "Price must be a positive number when provided";
        }

        setErrors(newErrors);
        return Object.keys(newErrors).length === 0;
    };

    const handleMint = () => {
        if (!validate()) return;

        if (!HAS_KNOWN_PACKAGE) {
            toast.error(
                "Package ID is not configured. Please set NEXT_PUBLIC_PACKAGE_ID before minting.",
            );
            return;
        }

        const tx = new Transaction();
        const withKioskListing =
            !!kioskId &&
            !!capId &&
            !!formData.price &&
            Number(formData.price) > 0;

        if (withKioskListing) {
            // コントラクトの mint_and_list を使用して一括で出品
            const priceMist = suiToMist(formData.price);
            tx.moveCall({
                target: `${PACKAGE_ID}::${MODULE_NAME}::mint_and_list`,
                arguments: [
                    tx.object(kioskId!),
                    tx.object(capId!),
                    tx.pure.string(formData.name),
                    tx.pure.string(formData.description),
                    tx.pure.string(formData.imageUrl),
                    tx.pure.u64(priceMist.toString()),
                ],
            });
        } else {
            // 通常の mint のみ
            mintNFT(tx, formData.name, formData.description, formData.imageUrl);
        }

        signAndExecute(
            {
                transaction: tx,
            },
            {
                onSuccess: (result) => {
                    toast.success("NFT minted successfully!", {
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
                    setFormData({
                        name: "",
                        description: "",
                        imageUrl: "",
                        price: "",
                    });
                    onOpenChange(false);
                    onSuccess?.();
                },
                onError: (error) => {
                    console.error("Mint error:", error);
                    toast.error("Failed to mint NFT", {
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
                    <DialogTitle>Mint New NFT</DialogTitle>
                    <DialogDescription>
                        Create a new NFT and place it in your Kiosk
                    </DialogDescription>
                </DialogHeader>

                <div className="space-y-4">
                    <div>
                        <Label htmlFor="name">Name</Label>
                        <Input
                            id="name"
                            value={formData.name}
                            onChange={(e) =>
                                setFormData({
                                    ...formData,
                                    name: e.target.value,
                                })
                            }
                            placeholder="My Awesome NFT"
                            maxLength={100}
                        />
                        {errors.name && (
                            <p className="text-sm text-destructive mt-1">
                                {errors.name}
                            </p>
                        )}
                    </div>

                    <div>
                        <Label htmlFor="description">Description</Label>
                        <Input
                            id="description"
                            value={formData.description}
                            onChange={(e) =>
                                setFormData({
                                    ...formData,
                                    description: e.target.value,
                                })
                            }
                            placeholder="A unique NFT for the workshop"
                            maxLength={500}
                        />
                        {errors.description && (
                            <p className="text-sm text-destructive mt-1">
                                {errors.description}
                            </p>
                        )}
                    </div>

                    <div>
                        <Label htmlFor="imageUrl">Image URL</Label>
                        <Input
                            id="imageUrl"
                            value={formData.imageUrl}
                            onChange={(e) =>
                                setFormData({
                                    ...formData,
                                    imageUrl: e.target.value,
                                })
                            }
                            placeholder="https://example.com/image.jpg"
                        />
                        {errors.imageUrl && (
                            <p className="text-sm text-destructive mt-1">
                                {errors.imageUrl}
                            </p>
                        )}
                    </div>

                    {/* Optional price for immediate listing */}
                    <div>
                        <Label htmlFor="price">
                            List Price (SUI, optional)
                        </Label>
                        <Input
                            id="price"
                            type="number"
                            step="0.000000001"
                            min="0"
                            value={formData.price}
                            onChange={(e) =>
                                setFormData({
                                    ...formData,
                                    price: e.target.value,
                                })
                            }
                            placeholder="0.1"
                        />
                        {errors.price && (
                            <p className="text-sm text-destructive mt-1">
                                {errors.price}
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
                    <Button onClick={handleMint} disabled={isPending}>
                        {isPending && (
                            <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                        )}
                        Mint NFT
                    </Button>
                </DialogFooter>
            </DialogContent>
        </Dialog>
    );
}
