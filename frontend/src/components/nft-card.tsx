/**
 * NFT表示カード（汎用）
 */

import Image from "next/image";
import {
    Card,
    CardContent,
    CardFooter,
    CardHeader,
} from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { mistToSui, formatNumber } from "@/lib/utils";
import { ExternalLink } from "lucide-react";
import { getObjectUrl } from "@/lib/constants";
import type { NFTDisplay } from "@/types";

interface NFTCardProps {
    objectId: string;
    display: NFTDisplay;
    price?: string; // MIST単位
    actionButton?: React.ReactNode;
    showExplorerLink?: boolean;
}

export function NFTCard({
    objectId,
    display,
    price,
    actionButton,
    showExplorerLink = false,
}: NFTCardProps) {
    return (
        <Card className="overflow-hidden">
            <CardHeader className="p-0">
                <div className="relative aspect-square w-full overflow-hidden bg-muted">
                    <Image
                        src={display.image_url}
                        alt={display.name}
                        fill
                        className="object-cover"
                        sizes="(max-width: 768px) 100vw, (max-width: 1200px) 50vw, 33vw"
                    />
                </div>
            </CardHeader>

            <CardContent className="p-4">
                <h3 className="font-semibold text-lg mb-1 truncate">
                    {display.name}
                </h3>
                <p className="text-sm text-muted-foreground line-clamp-2 mb-3">
                    {display.description}
                </p>

                {price && (
                    <div className="flex items-center gap-2">
                        <Badge
                            variant="secondary"
                            className="text-lg font-bold"
                        >
                            {formatNumber(mistToSui(price))} SUI
                        </Badge>
                    </div>
                )}

                {showExplorerLink && (
                    <a
                        href={getObjectUrl(objectId)}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="inline-flex items-center gap-1 text-sm text-muted-foreground hover:text-foreground transition-colors mt-2"
                    >
                        View on Explorer
                        <ExternalLink className="h-3 w-3" />
                    </a>
                )}
            </CardContent>

            {actionButton && (
                <CardFooter className="p-4 pt-0">{actionButton}</CardFooter>
            )}
        </Card>
    );
}
