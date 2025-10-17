import type {
    SuiClient,
    SuiEvent,
    SuiObjectResponse,
} from "@mysten/sui/client";
import type { ListedNFT, NFTDisplay } from "@/types";
import {
    ALLOWED_PUBLISHERS,
    MODULE_NAME,
    POLLING_INTERVAL,
    STRUCT_NAME,
} from "./constants";

const KIOSK_EVENT_PREFIX = {
    listed: "0x2::kiosk::ItemListed",
    purchased: "0x2::kiosk::ItemPurchased",
    delisted: "0x2::kiosk::ItemDelisted",
};

const KIOSK_EVENT_FILTER = {
    MoveEventModule: {
        package: "0x2",
        module: "kiosk",
    },
} as const;

const allowedPublisherSet = new Set(ALLOWED_PUBLISHERS);

interface ParsedKioskEvent {
    itemType: string;
    packageId: string;
    moduleName: string;
    structName: string;
}

function pick<T = any>(obj: any, candidates: string[]): T | undefined {
    for (const k of candidates) {
        if (obj && obj[k] !== undefined && obj[k] !== null) return obj[k];
    }
    return undefined;
}

function parseDisplay(obj: SuiObjectResponse): NFTDisplay | null {
    const data: any = (obj as any).data;
    const display = data?.display?.data ?? null;
    if (!display) return null;
    const name = display.name ?? "Untitled";
    const description = display.description ?? "";
    const image_url = display.image_url ?? display.imageUrl ?? "";
    return { name, description, image_url };
}

function parseInnerType(type: string): ParsedKioskEvent | null {
    const start = type.indexOf("<");
    const end = type.lastIndexOf(">");
    if (start === -1 || end === -1 || end <= start) return null;
    const inner = type.slice(start + 1, end).trim();
    const parts = inner.split("::");
    if (parts.length < 3) return null;
    const [packageRaw, moduleName, structRaw] = parts;
    const structName = structRaw.split("<")[0];
    const packageId = packageRaw.toLowerCase();

    if (moduleName !== MODULE_NAME || structName !== STRUCT_NAME) return null;

    if (allowedPublisherSet.size > 0) {
        if (!allowedPublisherSet.has(packageId)) return null;
    }

    return {
        itemType: inner,
        packageId,
        moduleName,
        structName,
    };
}

function parseRelevantKioskEvent(
    event: SuiEvent,
    expectedPrefix: string,
): ParsedKioskEvent | null {
    if (!event.type.startsWith(`${expectedPrefix}<`)) {
        return null;
    }

    return parseInnerType(event.type);
}

async function collectKioskEvents(
    client: SuiClient,
    expectedPrefix: string,
    targetMatches: number,
): Promise<Array<{ event: SuiEvent; parsed: ParsedKioskEvent }>> {
    const matches: Array<{ event: SuiEvent; parsed: ParsedKioskEvent }> = [];
    let cursor: { txDigest: string; eventSeq: string } | null = null;

    while (matches.length < targetMatches) {
        const res = await client.queryEvents({
            query: KIOSK_EVENT_FILTER,
            cursor: cursor ?? undefined,
            limit: Math.min(50, targetMatches * 2),
            order: "descending",
        });

        if (res.data.length === 0) break;

        for (const ev of res.data) {
            const parsed = parseRelevantKioskEvent(ev, expectedPrefix);
            if (!parsed) continue;
            matches.push({ event: ev, parsed });
            if (matches.length >= targetMatches) break;
        }

        if (!res.hasNextPage || !res.nextCursor) break;
        cursor = res.nextCursor as { txDigest: string; eventSeq: string };
    }

    return matches;
}

function normalizePackageId(packageId: string): string {
    const lower = packageId.toLowerCase();
    return lower.startsWith("0x") ? lower : `0x${lower}`;
}

export async function fetchActiveListings(
    client: SuiClient,
    opts?: { limit?: number },
): Promise<ListedNFT[]> {
    const limit = opts?.limit ?? 100;

    const listedEvents = await collectKioskEvents(
        client,
        KIOSK_EVENT_PREFIX.listed,
        Math.max(limit, 25),
    );

    type ListingCore = {
        itemId: string;
        kioskId: string;
        price: string; // bigint string (MIST)
        txDigest: string;
        owner?: string;
        itemType: string;
        packageId: string;
        moduleName: string;
        structName: string;
    };

    const byKey = new Map<string, ListingCore>();
    for (const { event: ev, parsed } of listedEvents) {
        const pj: any = (ev as any).parsedJson ?? {};
        const itemId = (
            pick<string>(pj, ["itemId", "item_id", "objectId"]) ?? ""
        ).toString();
        const kioskId = (
            pick<string>(pj, ["kiosk", "kioskId", "kiosk_id"]) ?? ""
        ).toString();
        const price = (
            pick<string>(pj, ["price", "list_price"]) ?? "0"
        ).toString();
        const owner = pick<string>(pj, ["seller", "owner", "lister"]) as
            | string
            | undefined;
        const txDigest = (ev as any).id?.txDigest ?? "";
        if (!itemId || !kioskId) continue;
        const key = `${itemId}::${kioskId}`;
        if (!byKey.has(key)) {
            byKey.set(key, {
                itemId,
                kioskId,
                price,
                txDigest,
                owner,
                itemType: parsed.itemType,
                packageId: normalizePackageId(parsed.packageId),
                moduleName: parsed.moduleName,
                structName: parsed.structName,
            });
        }
    }

    if (byKey.size === 0) return [];

    // 2) Load cancellations and purchases to filter out inactive listings
    const purchasedEvents = await collectKioskEvents(
        client,
        KIOSK_EVENT_PREFIX.purchased,
        Math.max(limit, 25),
    );
    for (const { event: ev } of purchasedEvents) {
        const pj: any = (ev as any).parsedJson ?? {};
        const itemId = (
            pick<string>(pj, ["itemId", "item_id"]) ?? ""
        ).toString();
        const kioskId = (
            pick<string>(pj, ["kiosk", "sellerKiosk", "kiosk_id"]) ?? ""
        ).toString();
        if (!itemId || !kioskId) continue;
        byKey.delete(`${itemId}::${kioskId}`);
    }
    const delistedEvents = await collectKioskEvents(
        client,
        KIOSK_EVENT_PREFIX.delisted,
        Math.max(limit, 25),
    );
    for (const { event: ev } of delistedEvents) {
        const pj: any = (ev as any).parsedJson ?? {};
        const itemId = (
            pick<string>(pj, ["itemId", "item_id"]) ?? ""
        ).toString();
        const kioskId = (
            pick<string>(pj, ["kiosk", "kioskId", "kiosk_id"]) ?? ""
        ).toString();
        if (!itemId || !kioskId) continue;
        byKey.delete(`${itemId}::${kioskId}`);
    }

    // 3) Hydrate display metadata in parallel
    const core = Array.from(byKey.values()).slice(0, limit);
    const objects = await Promise.allSettled(
        core.map((c) =>
            client.getObject({ id: c.itemId, options: { showDisplay: true } }),
        ),
    );

    const res: ListedNFT[] = [];
    core.forEach((c, index) => {
        const result = objects[index];
        if (result.status !== "fulfilled") return;
        const display = parseDisplay(result.value);
        if (!display) return;

        res.push({
            itemId: c.itemId,
            kioskId: c.kioskId,
            price: c.price,
            display,
            owner: c.owner ?? "",
            txDigest: c.txDigest,
            itemType: c.itemType,
            packageId: c.packageId,
            moduleName: c.moduleName,
            structName: c.structName,
        });
    });

    return res;
}

export function subscribeActiveListings(
    client: SuiClient,
    onChange: () => void,
): () => void {
    let unsubscribeFn: (() => void) | null = null;
    let cancelled = false;

    client
        .subscribeEvent({
            filter: KIOSK_EVENT_FILTER,
            onMessage: (event) => {
                if (
                    parseRelevantKioskEvent(event, KIOSK_EVENT_PREFIX.listed) ||
                    parseRelevantKioskEvent(
                        event,
                        KIOSK_EVENT_PREFIX.purchased,
                    ) ||
                    parseRelevantKioskEvent(event, KIOSK_EVENT_PREFIX.delisted)
                ) {
                    onChange();
                }
            },
        })
        .then((unsub) => {
            if (cancelled) {
                unsub();
            } else {
                unsubscribeFn = unsub;
            }
        })
        .catch((error) => {
            console.error("Failed to subscribe to kiosk events", error);
        });

    return () => {
        cancelled = true;
        if (unsubscribeFn) {
            unsubscribeFn();
        }
    };
}

export function startPollingListings(
    _client: SuiClient,
    onTick: () => void,
    intervalMs: number = POLLING_INTERVAL,
): () => void {
    const id = setInterval(onTick, intervalMs);
    return () => clearInterval(id);
}
