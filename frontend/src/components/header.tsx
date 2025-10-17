"use client";

/**
 * アプリケーションヘッダー
 */

import { ConnectButton } from "@mysten/dapp-kit";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { cn } from "@/lib/utils";
import { ThemeToggle } from "./theme-toggle";

export function Header() {
    const pathname = usePathname();

    return (
        <header className="border-b">
            <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
                <div className="flex h-16 items-center justify-between">
                    {/* Logo and Navigation */}
                    <div className="flex items-center gap-8">
                        <Link href="/" className="text-xl font-bold">
                            NFT Marketplace
                        </Link>

                        <nav className="flex gap-4">
                            <Link
                                href="/"
                                className={cn(
                                    "rounded-md px-3 py-2 text-sm font-medium transition-colors",
                                    pathname === "/"
                                        ? "bg-primary text-primary-foreground"
                                        : "text-muted-foreground hover:bg-accent hover:text-accent-foreground",
                                )}
                            >
                                Home
                            </Link>
                            <Link
                                href="/my"
                                className={cn(
                                    "rounded-md px-3 py-2 text-sm font-medium transition-colors",
                                    pathname === "/my"
                                        ? "bg-primary text-primary-foreground"
                                        : "text-muted-foreground hover:bg-accent hover:text-accent-foreground",
                                )}
                            >
                                My Kiosk
                            </Link>
                        </nav>
                    </div>

                    {/* Wallet and Theme */}
                    <div className="flex items-center gap-4">
                        <ConnectButton />
                        <ThemeToggle />
                    </div>
                </div>
            </div>
        </header>
    );
}
