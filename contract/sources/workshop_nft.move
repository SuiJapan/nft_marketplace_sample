/// モジュール: workshop_nft
///
/// このモジュールは、Sui NFTマーケットプレイスワークショップ向けの包括的なNFT実装を提供します。
/// 以下の重要なSui Moveの概念を示しています：
///
/// ## コア機能
/// - WorkshopNft: 表示メタデータとタイムスタンプを持つNFT構造体
/// - Mint関数: Clock統合による新しいNFTの作成
/// - Kiosk統合: マーケットプレイスでのNFT販売リスト機能
/// - TransferPolicy: 安全なNFT取引を可能にする
///
/// ## 高度なSui Moveの概念（ワークショップの焦点）
///
/// ### 1. Clock統合
/// - `sui::clock::Clock`を使用してNFT作成タイムスタンプを記録
/// - スマートコントラクトでの時間ベース機能を実演
/// - ユースケース: タイムスタンプ、期間限定機能、オークション
///
/// ### 2. Dynamic Fields（`sui::dynamic_field`）
/// - 実行時にオブジェクトに任意のデータを追加
/// - 格納される値は`store`アビリティのみが必要
/// - ラップされたデータ - 外部IDからは直接アクセス不可
/// - ユースケース: 拡張可能なメタデータ、ゲーム属性、動的プロパティ
///
/// ### 3. Dynamic Object Fields（`sui::dynamic_object_field`）
/// - NFTに他のSuiオブジェクトを添付
/// - 格納されるオブジェクトは`key` + `store`アビリティが必要
/// - オブジェクトはIDによって独立してアクセス可能なまま
/// - ユースケース: コンポーザブルNFT、装備システム、ネストされたオブジェクト
///
/// ## ワークショップの学習パス
/// 1. Clockを使用した基本的なNFTミンティング
/// 2. Dynamic Fieldメタデータ（レアリティ、レベル）の追加
/// 3. Dynamic Object Fieldアクセサリー（装備）の添付
/// 4. フル機能NFTでのすべての機能の組み合わせ
///
module contract::workshop_nft;

use std::string::{Self as string, String};
use sui::clock::Clock;
use sui::display;
use sui::dynamic_field as df;
use sui::dynamic_object_field as dof;
use sui::kiosk::{Kiosk, KioskOwnerCap};
use sui::package;
use sui::package::Publisher;
use sui::transfer::{public_share_object, public_transfer};
use sui::transfer_policy;

// ===== エラーコード =====

/// エラー: name、description、urlに空文字列が指定されました
const EEmptyString: u64 = 1;

/// エラー: 無効な価格（0より大きい必要があります）
const EInvalidPrice: u64 = 2;

// ===== 構造体 =====

/// モジュール用のOne-Time-Witness
public struct WORKSHOP_NFT has drop {}

/// Metadata: NFT属性のためのDynamic Fieldデータ
/// この構造体はDynamic Fieldの使用方法を示します - 任意のNFTに動的に追加可能
/// - rarity: レアリティレベル（1=Common、2=Rare、3=Epic、4=Legendary）
/// - level: アイテムレベル（ゲームメカニクスで使用）
public struct Metadata has store {
    rarity: u8,
    level: u64,
}

/// Accessory: NFTに添付できる独立したオブジェクト
/// この構造体はDynamic Object Fieldの使用方法を示します - 独立してアクセス可能なまま
/// - id: 一意の識別子（Dynamic Object Fieldに必要）
/// - accessory_type: アクセサリーの種類（例: "hat"、"weapon"、"shield"）
/// - bonus_value: このアクセサリーが提供する数値ボーナス
public struct Accessory has key, store {
    id: UID,
    accessory_type: String,
    bonus_value: u64,
}

/// WorkshopNft: メタデータを持つシンプルなNFT
/// - id: NFTオブジェクトの一意の識別子
/// - name: NFTの表示名
/// - description: NFTの説明
/// - url: NFTの画像URL
/// - created_at: NFTが作成されたタイムスタンプ（Unix Epochからのミリ秒）
public struct WorkshopNft has key, store {
    id: UID,
    name: String,
    description: String,
    url: String,
    created_at: u64,
}

// ===== モジュールの初期化 =====

/// モジュールを初期化
/// - フロントエンドのメタデータ表示用にDisplay<WorkshopNft>を作成・設定
/// - TransferPolicy<WorkshopNft>を作成・共有（Kiosk取引を可能化）
/// - Publisherをデプロイヤーに転送
#[allow(lint(share_owned))]
fun init(otw: WORKSHOP_NFT, ctx: &mut TxContext) {
    // Publisherオブジェクトを要求
    let publisher = package::claim(otw, ctx);

    // WorkshopNft用のDisplayオブジェクトをフィールド付きで作成
    let keys = vector[
        string::utf8(b"name"),
        string::utf8(b"description"),
        string::utf8(b"image_url"),
    ];
    let values = vector[
        string::utf8(b"{name}"),
        string::utf8(b"{description}"),
        string::utf8(b"{url}"),
    ];
    let mut display = display::new_with_fields<WorkshopNft>(&publisher, keys, values, ctx);
    // Move 2024のメソッド構文: レシーバーの型と同じモジュールから関数を呼び出す
    display.update_version();
    public_share_object(display);

    // TransferPolicy<WorkshopNft>を作成・共有（Kiosk取引を可能化）
    let (policy, policy_cap) = transfer_policy::new<WorkshopNft>(&publisher, ctx);
    public_share_object(policy);
    public_transfer(policy_cap, ctx.sender());

    // Publisherをデプロイヤーに転送
    public_transfer(publisher, ctx.sender());
}

// ===== コアNFT関数 =====

/// 新しいWorkshopNftを作成（コアロジック）
///
/// パラメータ:
/// - name: NFT名（空であってはならない）
/// - description: NFT説明（空であってはならない）
/// - url: NFT画像URL（空であってはならない）
/// - clock: 現在のタイムスタンプを取得するClockオブジェクト
/// - ctx: トランザクションコンテキスト
///
/// 戻り値: WorkshopNftオブジェクト
///
/// 中断条件: いずれかの文字列パラメータが空の場合
public(package) fun mint_nft(
    name: String,
    description: String,
    url: String,
    clock: &Clock,
    ctx: &mut TxContext,
): WorkshopNft {
    // 入力を検証
    assert!(!name.is_empty(), EEmptyString);
    assert!(!description.is_empty(), EEmptyString);
    assert!(!url.is_empty(), EEmptyString);

    // Clockから現在のタイムスタンプを取得
    let created_at = clock.timestamp_ms();

    // NFTを作成して返す
    WorkshopNft {
        id: object::new(ctx),
        name,
        description,
        url,
        created_at,
    }
}

/// 新しいWorkshopNftをミント（エントリー関数）
///
/// これはmint_nftの薄いラッパーで、NFTを呼び出し元に転送します。
///
/// パラメータ:
/// - name: NFT名（空であってはならない）
/// - description: NFT説明（空であってはならない）
/// - url: NFT画像URL（空であってはならない）
/// - clock: 現在のタイムスタンプを取得するClockオブジェクト
/// - ctx: トランザクションコンテキスト
///
/// 中断条件: いずれかの文字列パラメータが空の場合
entry fun mint(
    name: String,
    description: String,
    url: String,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let nft = mint_nft(name, description, url, clock, ctx);
    public_transfer(nft, ctx.sender());
}

// ===== Kiosk統合関数 =====

/// NFTをKioskに配置し、販売用にリスト（コアロジック）
///
/// パラメータ:
/// - kiosk: Kioskへの可変参照
/// - kiosk_cap: KioskOwnerCapへの参照
/// - nft: 配置してリストするWorkshopNft
/// - price: MISTでのリスト価格（1 SUI = 1,000,000,000 MIST）
///
/// 中断条件: 価格が0または負の場合
public(package) fun place_and_list_core(
    kiosk: &mut Kiosk,
    kiosk_cap: &KioskOwnerCap,
    nft: WorkshopNft,
    price: u64,
) {
    // 価格を検証
    assert!(price > 0, EInvalidPrice);

    // NFTをKioskに配置し、販売用にリスト
    // レシーバーの型と同じモジュールで関数が定義されているため、Kioskでメソッド構文を使用
    kiosk.place_and_list(kiosk_cap, nft, price);
}

/// 新しいWorkshopNftをミントし、即座にKioskにリスト（エントリー関数）
///
/// これは、ミントとリストを1つのトランザクションで組み合わせた便利な関数です。
///
/// パラメータ:
/// - kiosk: Kioskへの可変参照
/// - kiosk_cap: KioskOwnerCapへの参照
/// - name: NFT名（空であってはならない）
/// - description: NFT説明（空であってはならない）
/// - url: NFT画像URL（空であってはならない）
/// - price: MISTでのリスト価格（0より大きい必要がある）
/// - clock: 現在のタイムスタンプを取得するClockオブジェクト
/// - ctx: トランザクションコンテキスト
///
/// 中断条件: いずれかの検証が失敗した場合
entry fun mint_and_list(
    kiosk: &mut Kiosk,
    kiosk_cap: &KioskOwnerCap,
    name: String,
    description: String,
    url: String,
    price: u64,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    // NFTをミント
    let nft = mint_nft(name, description, url, clock, ctx);

    // Kioskに配置してリスト
    place_and_list_core(kiosk, kiosk_cap, nft, price);
}

// ===== Dynamic Field関数 =====
// Dynamic Fieldは実行時にオブジェクトに任意のデータを追加できます。
// 格納される値は`store`アビリティのみが必要です。

/// Dynamic Fieldを使用してNFTにメタデータを追加
///
/// これは作成後にNFTに追加データを添付する方法を示します。
/// Dynamic Fieldは、構造体定義を変更せずにオブジェクトを拡張するのに便利です。
///
/// パラメータ:
/// - nft: NFTへの可変参照
/// - rarity: レアリティレベル（1=Common、2=Rare、3=Epic、4=Legendary）
/// - level: アイテムレベル
///
/// 注意: NFTはメタデータを「ラップ」します - 外部からIDでアクセスできません
entry fun add_metadata(
    nft: &mut WorkshopNft,
    rarity: u8,
    level: u64,
) {
    let metadata = Metadata { rarity, level };
    df::add(&mut nft.id, b"metadata", metadata);
}

/// NFTからメタデータを取得
///
/// パラメータ:
/// - nft: NFTへの参照
///
/// 戻り値: (rarity, level)タプル
///
/// 中断条件: メタデータが存在しない場合
public fun get_metadata(nft: &WorkshopNft): (u8, u64) {
    let metadata = df::borrow<vector<u8>, Metadata>(&nft.id, b"metadata");
    (metadata.rarity, metadata.level)
}

/// NFTのメタデータを更新
///
/// パラメータ:
/// - nft: NFTへの可変参照
/// - new_level: 新しいレベル値
///
/// 中断条件: メタデータが存在しない場合
entry fun update_metadata_level(
    nft: &mut WorkshopNft,
    new_level: u64,
) {
    let metadata = df::borrow_mut<vector<u8>, Metadata>(&mut nft.id, b"metadata");
    metadata.level = new_level;
}

/// NFTがメタデータを持っているか確認
///
/// パラメータ:
/// - nft: NFTへの参照
///
/// 戻り値: メタデータが存在する場合true
public fun has_metadata(nft: &WorkshopNft): bool {
    df::exists_<vector<u8>>(&nft.id, b"metadata")
}

/// NFTからメタデータを削除
///
/// パラメータ:
/// - nft: NFTへの可変参照
///
/// 戻り値: 削除されたMetadata
///
/// 中断条件: メタデータが存在しない場合
public fun remove_metadata(nft: &mut WorkshopNft): Metadata {
    df::remove<vector<u8>, Metadata>(&mut nft.id, b"metadata")
}

// ===== Dynamic Object Field関数 =====
// Dynamic Object Fieldは他のSuiオブジェクト（`key` + `store`アビリティを持つ）を格納します。
// 通常のDynamic Fieldとは異なり、これらのオブジェクトは独自のIDでアクセス可能なままです。

/// 新しいAccessoryオブジェクトを作成
///
/// パラメータ:
/// - accessory_type: タイプ名（例: "hat"、"weapon"）
/// - bonus_value: 数値ボーナス値
/// - ctx: トランザクションコンテキスト
///
/// 戻り値: Accessoryオブジェクト
public fun create_accessory(
    accessory_type: String,
    bonus_value: u64,
    ctx: &mut TxContext,
): Accessory {
    Accessory {
        id: object::new(ctx),
        accessory_type,
        bonus_value,
    }
}

/// Dynamic Object Fieldを使用してAccessoryをNFTに添付
///
/// これは、独立したオブジェクトをNFTに添付する方法を示します。
/// アクセサリーは、添付されていても独自のIDでアクセス可能なままです。
///
/// パラメータ:
/// - nft: NFTへの可変参照
/// - accessory: 添付するAccessoryオブジェクト
/// - slot_name: アクセサリースロットの名前（例: "head"、"weapon"）
entry fun attach_accessory(
    nft: &mut WorkshopNft,
    accessory: Accessory,
    slot_name: vector<u8>,
) {
    dof::add(&mut nft.id, slot_name, accessory);
}

/// 添付されたAccessoryを借用（読み取り専用）
///
/// パラメータ:
/// - nft: NFTへの参照
/// - slot_name: アクセサリースロットの名前
///
/// 戻り値: Accessoryへの参照
///
/// 中断条件: スロットにAccessoryが存在しない場合
public fun borrow_accessory(
    nft: &WorkshopNft,
    slot_name: vector<u8>,
): &Accessory {
    dof::borrow<vector<u8>, Accessory>(&nft.id, slot_name)
}

/// 添付されたAccessoryを借用（可変）
///
/// パラメータ:
/// - nft: NFTへの可変参照
/// - slot_name: アクセサリースロットの名前
///
/// 戻り値: Accessoryへの可変参照
///
/// 中断条件: スロットにAccessoryが存在しない場合
public fun borrow_accessory_mut(
    nft: &mut WorkshopNft,
    slot_name: vector<u8>,
): &mut Accessory {
    dof::borrow_mut<vector<u8>, Accessory>(&mut nft.id, slot_name)
}

/// NFTが特定のスロットにアクセサリーを持っているか確認
///
/// パラメータ:
/// - nft: NFTへの参照
/// - slot_name: アクセサリースロットの名前
///
/// 戻り値: アクセサリーが存在する場合true
public fun has_accessory(
    nft: &WorkshopNft,
    slot_name: vector<u8>,
): bool {
    dof::exists_<vector<u8>>(&nft.id, slot_name)
}

/// NFTからAccessoryを取り外す
///
/// パラメータ:
/// - nft: NFTへの可変参照
/// - slot_name: アクセサリースロットの名前
///
/// 戻り値: 取り外されたAccessoryオブジェクト
///
/// 中断条件: スロットにAccessoryが存在しない場合
public fun detach_accessory(
    nft: &mut WorkshopNft,
    slot_name: vector<u8>,
): Accessory {
    dof::remove<vector<u8>, Accessory>(&mut nft.id, slot_name)
}

/// アクセサリーを取り外して送信者に転送するエントリー関数
///
/// パラメータ:
/// - nft: NFTへの可変参照
/// - slot_name: アクセサリースロットの名前
/// - ctx: トランザクションコンテキスト
entry fun detach_and_transfer_accessory(
    nft: &mut WorkshopNft,
    slot_name: vector<u8>,
    ctx: &TxContext,
) {
    let accessory = detach_accessory(nft, slot_name);
    public_transfer(accessory, ctx.sender());
}

// ===== 統合ワークショップデモ関数 =====

/// 包括的なデモ: すべての機能を持つNFTを作成
///
/// この関数は、Clock、Dynamic Field、Dynamic Object Fieldの動作を示します。
/// タイムスタンプ、メタデータ、添付されたアクセサリーを持つフル機能のNFTを作成します。
///
/// パラメータ:
/// - name: NFT名
/// - description: NFT説明
/// - url: NFT画像URL
/// - rarity: レアリティレベル（1-4）
/// - level: 初期レベル
/// - accessory_type: 添付するアクセサリーのタイプ
/// - bonus_value: アクセサリーのボーナス値
/// - clock: タイムスタンプ用のClockオブジェクト
/// - ctx: トランザクションコンテキスト
entry fun mint_full_featured_nft(
    name: String,
    description: String,
    url: String,
    rarity: u8,
    level: u64,
    accessory_type: String,
    bonus_value: u64,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    // 1. Clockタイムスタンプを使用してNFTを作成
    let mut nft = mint_nft(name, description, url, clock, ctx);

    // 2. Dynamic Fieldを使用してメタデータを追加
    let metadata = Metadata { rarity, level };
    df::add(&mut nft.id, b"metadata", metadata);

    // 3. Dynamic Object Fieldを使用してアクセサリーを作成・添付
    let accessory = Accessory {
        id: object::new(ctx),
        accessory_type,
        bonus_value,
    };
    dof::add(&mut nft.id, b"main_accessory", accessory);

    // 4. フル機能のNFTを送信者に転送
    public_transfer(nft, ctx.sender());
}

/// NFTの作成タイムスタンプを取得
///
/// パラメータ:
/// - nft: NFTへの参照
///
/// 戻り値: ミリ秒単位の作成タイムスタンプ
public fun get_created_at(nft: &WorkshopNft): u64 {
    nft.created_at
}

// ===== テスト専用関数 =====

#[test_only]
/// テスト用のWORKSHOP_NFTを作成
public fun test_init(ctx: &mut TxContext) {
    init(WORKSHOP_NFT {}, ctx);
}
