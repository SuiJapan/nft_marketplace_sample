"use client";

/**
 * アプリケーション全体のプロバイダ
 */

import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { SuiClientProvider, WalletProvider } from "@mysten/dapp-kit";
import { ThemeProvider } from "next-themes";
import { Toaster } from "@/components/ui/sonner";
import { networkConfig, defaultNetwork } from "@/lib/sui-client";
import { useState } from "react";
import "@mysten/dapp-kit/dist/index.css";

export function Providers({ children }: { children: React.ReactNode }) {
    const [queryClient] = useState(() => new QueryClient());

    return (
        <ThemeProvider attribute="class" defaultTheme="system" enableSystem>
            <QueryClientProvider client={queryClient}>
                <SuiClientProvider
                    networks={networkConfig}
                    defaultNetwork={defaultNetwork}
                >
                    <WalletProvider autoConnect>
                        {children}
                        <Toaster />
                    </WalletProvider>
                </SuiClientProvider>
            </QueryClientProvider>
        </ThemeProvider>
    );
}
