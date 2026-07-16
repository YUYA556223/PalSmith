# PalSmith 設計書

「JSON + PNG だけで新アイテム・新レシピ・テクノロジーツリー・配置物・挙動・UIを追加できる」
ことを目指す PalSchema コンパニオン型のベースMod。コンテンツMod作者が UE5 を一切触らずに済む状態がゴール。

- 名称: **PalSmith**(2026-07-16 決定。仮称PalForgeは既存のブリーディング計算ツール
  [palbreedingcalc.com](https://palbreedingcalc.com/) と衝突するため回避。PalWorksもAnimation Frameworkが存在)
- ステータス: **設計+前提検証フェーズ**(2026-07-16 調査・設計、PoC雛形作成済み)

## 0. 設計原則: 「面白いModが作れる」こと

スピードアップ等の数値調整だけでは面白いModは生まれない。PalSmithは
**「できること」を拡張する**基盤を目指す:

- アイテムは「持てる」だけでなく「**使える**」(使用時に何かが起きる)
- 「**配置できる**」(ワールドに置けて、置いたものが機能する)
- 「**動く**」(定期処理・インタラクト・生産などの独自挙動)

→ これを実現する **Behavior レイヤー(⑥)** が本体の中核機能。データ追加(①〜③)は
その土台に過ぎない。

---

## 1. 前提知識: Palworld Modding の現状(2026-07 調査)

### レイヤー構造

```
Unreal Engine 5 (Palworld本体)
└─ UE4SS (Palworld専用fork / RE-UE4SS)   ← ランタイム基盤。Lua / C++ Mod / BPローダー
   └─ PalSchema                           ← JSONでDataTable/Blueprint編集。行追加=新規コンテンツ可
      └─ 各コンテンツMod (JSON)
```

### 既存基盤ができること・できないこと

| 領域 | 現状 | 備考 |
|---|---|---|
| 挙動変更(フック) | ✅ UE4SS Lua | サーバー側のみで完結可(AdminCommands方式) |
| 新アイテム・新パル・スキン等のデータ追加 | ✅ PalSchema | DataTable行追加。`items`は`Name`/`Description`/`Recipe`をインライン記述可 |
| 新レシピ | ✅ PalSchema | `items`の`Recipe`ブロック or `raw` |
| 新規配置物(建物) | ✅ PalSchema `buildings` | `Technology`ブロックでツリー登録まで一括。BPは既存流用 or 自作pak |
| テクノロジーツリーへのノード追加 | ✅(建物) / 🔶(アイテム) | 建物は`Technology`ブロック。アイテムは`raw`で`DT_TechnologyRecipeUnlock`行追加(列名要検証=PoC-A) |
| **新規アイコン・テクスチャ(PNG直読み)** | ✅ **PalSchema 0.5.0+** | `<mod>/resources/images/*.png` → 任意のTSoftObjectPtrフィールドで `$resource/<mod名>/<ファイル名>` 参照。**pak化不要** |
| 新規3Dモデルのランタイム読み込み | 🔶 **静的メッシュは可能な見込み** | Palworldは`ProceduralMeshComponent`/`DynamicMeshComponent`を同梱→リフレクション経由(ABI非依存)で実行時生成できる(§2⑦、V5検証中)。スケルタル(Pal本体)は対象外 |
| cook済みアセットの同梱 | ✅ PalSchema | Mod内 `paks/` サブフォルダの .pak を自動読み込み |
| アイテム使用/配置イベントのフック | 🔶 未検証 | Behaviorレイヤーの生死を分ける。**V2/V3で最優先検証** |

> ⚠️ 教訓: PalSchemaの公開Webドキュメントはリポジトリ内docs(website/docs)より古いことがある。
> 最新仕様は [GitHubリポジトリ](https://github.com/Okaetsu/PalSchema) を直接見る(v0.6.0時点の調査)。

### PalSchema のフォルダ規約(v0.6.0 ソース確認済み)

`appearance` / `blueprints` / `buildings` / `enums` / `helpguide` / `items` / `pals` /
`raw`(安全ロジックなしの汎用DataTable編集)/ `resources`(画像インポート)/ `skins` /
`spawns` / `translations`

- 配置先: `Pal/Binaries/Win64/ue4ss/Mods/PalSchema/mods/<Mod名>/`
- JSON自動リロードあり(ゲーム起動中に編集→即反映)
- 不正な列名は `Property 'X' not found` と警告される → 列名特定に使える
- テクノロジーツリー関連テーブル(PalBuildingModLoader.cpp:62-64 で確認):
  `DT_TechnologyRecipeUnlock` / `DT_TechnologyNameText` / `DT_TechnologyDescText`

### 原理的な制約(超重要)

**Palworldにはサーバー→クライアントのアセット配信機構がない**(Minecraftのサーバーリソースパック相当が存在しない)。
よって新アイテム・レシピ・ツリーなどのゲームプレイデータは**サーバーとクライアント両方に同一Modが必要**。
Vortexが面倒を見るのはクライアント側だけで、専用サーバー(palserver)には手動配置の運用が残る。

---

## 2. PalSmithの勝ち筋(空白地帯)

データ層はPalSchemaが完成しているので再発明しない。上に乗せるレイヤーが差別化ポイント:

### ① 基底クラスライブラリ(cook済みpak)

自分が一度だけ PalworldModdingKit (UE5) で汎用Blueprint基底クラス群を作って pak 化し、PalSmithに同梱する:

- `BP_GenericConsumable` / `BP_GenericWeapon` / `BP_GenericBuilding` など
- 汎用マテリアル、Behaviorディスパッチ用のイベント発火点を仕込んだ「PalSmith対応」基底クラス

コンテンツMod作者は JSON の `actorClass` / `BlueprintClassSoft` でこれらを参照するだけ。
**UE5不要で新アイテム・新配置物が作れる**ようになる。現状誰もやっていない空白地帯。

> 補足: 既存ゲーム内BPの流用でも多くのケースは賄える(V1で検証)。基底クラスpakは
> 「既存BPでは表現できない挙動の受け皿」として後続フェーズで作る。

### ② ビジュアル層 — PalSchema `$resource` を採用(自作不要になった)

当初「ランタイムPNGローダーを自作する」計画だったが、**PalSchema 0.5.0 の
Importing Images 機能がそのもの**だった。PalSmithはこれを標準規約として採用する:

- `<mod>/resources/images/*.png` を置き、`IconTexture` 等のTSoftObjectPtrフィールドに
  `$resource/<mod名>/<ファイル名>` と書くだけ
- アイテムアイコン・建物アイコン・パルアイコン・サバイバルガイド画像等に使える
- 残検証: 専用サーバー+クライアント構成での実機確認(PoC-Aに統合)

### ③ オーサリング層(1ファイル定義)

素のPalSchemaでは新アイテム+ツリー解放を作るのに複数フォルダ/テーブルにまたがるJSONが必要。
PalSmithが `pack.jsonc` 1ファイル(アイテム定義・レシピ・ツリー位置・翻訳・アイコン・**Behavior**)を読み、
内部でPalSchema形式に展開する。PalSchemaのJSON自動リロードと組み合わせ、編集→即反映の開発体験を出す。

### ④ UIフレームワーク(宣言的メニュー/HUD)

①の方式をUIに適用: **汎用のデータ駆動Widget(UMG)を一度だけcookして基底pakに同梱し、
コンテンツModはJSONでメニューを宣言するだけ**にする。

技術的裏付け:

- UE4SSの **BPModLoader(LogicMods)** が `Paks/LogicMods` 内のpakから
  ModActor+WidgetBlueprintをロードする公式の仕組みを持つ。
  コミュニティでも「プレイヤー向けUIはWidget一択(UE4SS GUIコンソール/ImGuiはデバッグ用)」が定説
- UE4SS Luaには `RegisterKeyBind`(キー割り当て)があり、
  `UWidgetBlueprintLibrary::Create` 経由でロード済みWidgetクラスをLuaから生成→`AddToViewport` できる見込み
- Widget側に `SetTitle` / `AddEntry(id, text, icon)` / `OnEntryClicked(id)` のような
  BP関数を生やしておけば、Luaから `RegisterHook` でクリックを受け取れる(フック親和設計)
- スタイルはPalworld本体のフォント/テクスチャをソフト参照すればネイティブな見た目にできる

提供アーキタイプ(想定): `WBP_Smith_ListMenu` / `WBP_Smith_GridMenu` / `WBP_Smith_Dialog` / `WBP_Smith_HudOverlay`

**既存ゲームUIへの差し込み**(ポーズメニューにタブ追加等)は、既存WBPインスタンスのフック+子要素注入で
原理的には可能だが、Widgetごとのリバースエンジニアリングが必要でアップデートに脆い。
→ 汎用化はせず、PalSmith側で保守する「厳選注入ポイント」を数カ所だけ提供する方針。

### ⑤ アクション/イベントシステム

- **アクション**: `open_menu` / `run_command` / `send_chat` / `lua_callback` /
  `server_action`(サーバー権威の処理: アイテム付与等)をJSONから参照できる形で登録
- **イベントバス**: ゲームイベント(プレイヤー参加、チャット、レベルアップ等)を
  コンテンツModが購読できるフックの抽象化。`__knowledges` の検証済みフック群がそのまま資産になる
- **クライアント↔サーバー通信**: Mod用の公式RPCは存在しないため、現実解は
  **チャットメッセージをトランスポートに使うプロトコル**(`smith://` プレフィックス)。
  クライアントの `server_action` をエンコードしてチャット送信→サーバー側PalSmithが
  `BroadcastChatMessage` フックで受信・実行。表示抑制が可能かは要検証(PoC-F)

### ⑥ Behavior レイヤー(本体の中核)★

「アイテムを追加しても、ただ持てるだけでは面白くない」を解決する層。
コンテンツパックがゲームオブジェクトに**挙動を宣言**できるようにする:

```jsonc
// pack.jsonc 内のアイテム定義(案)
{
  "id": "mypack:healing_totem",
  "kind": "building",                      // item | building
  "base": "existing:/Game/.../BP_Campfire", // 既存BP流用 or smith:GenericBuilding
  "behaviors": {
    "onPlace":    { "handler": "smith:announce", "args": { "text": "トーテム設置!" } },
    "onInteract": { "handler": "smith:give_item", "args": { "item": "Potion", "count": 1, "cooldownSec": 300 } },
    "onTick":     { "intervalSec": 10, "handler": "smith:heal_nearby", "args": { "radius": 500, "amount": 50 } }
  }
}
```

実装方式:

- **ディスパッチャ**: PalSmithランタイム(サーバー側Lua/C++)がゲーム関数をフックし、
  発生イベントから対象オブジェクトのID(StaticItemId / BuildObjectId)を特定して、
  登録済みBehaviorをルックアップ・実行する
- **標準ハンドラライブラリ**: 検証済みのCheatManager/PalUtility群(アイテム付与・Pal召喚・
  経験値・テレポート・アナウンス等)をJSONから使える形で提供。
  **コンテンツパック自身のLua同梱は当面不可**(任意コード実行はセキュリティ・審査面で危険。
  上級者向けオプトインとして将来検討)
- **サーバー権威**: Behavior実行は原則サーバー側。マルチで正しく反映される
- **状態**: クールダウン等はF4の永続化ストレージに保存

対応イベント(検証対象):

| イベント | フック対象(要調査) | 検証 |
|---|---|---|
| onUse(アイテム使用) | インベントリの使用系関数(Live Viewで特定) | **V2** |
| onPlace(配置完了) | 建築完了系関数 | V3 |
| onInteract(配置物に対話) | インタラクト系関数 | V3 |
| onTick(定期処理) | `LoopAsync`(UE4SS Lua標準)+対象オブジェクト列挙 | 低リスク |
| onCraft(クラフト完了) | 生産完了系関数 | V3 |

限界の明示: 「アイテムがベルトコンベアを流れる」級の**完全新規メカニクス**は、
既存オブジェクト+Behaviorの組み合わせでエミュレートできる範囲を超えたら
①のcook済みカスタムBPが必要になる。Behaviorレイヤーは「既存の物理表現 × 新しいロジック」までを守備範囲とする。

### ⑦ ランタイム3Dオブジェクト(ProceduralMesh、ABI非依存)★2026-07-16に方針転換

当初「ランタイム3Dモデル読み込みはABI依存で非現実的」としていたが、CXXHeaderDump調査で
**PalworldがProceduralMeshComponent一式をゲーム本体に同梱している**ことが判明。
必要なAPIがすべてリフレクション(UFunction)経由で呼べる = **ABI非依存・アップデート耐性あり**:

| ステップ | 確認済みAPI(すべてBlueprintCallable) |
|---|---|
| コンポーネント実行時追加 | `AActor::AddComponentByClass(Class, bManualAttachment, RelativeTransform, bDeferredFinish)` |
| メッシュ生成(コリジョン付き) | `UProceduralMeshComponent::CreateMeshSection(Vertices, Triangles, Normals, UV0, ..., bCreateCollision)` |
| アクタースポーン | `UGameplayStatics::BeginDeferredActorSpawnFromClass` + `FinishSpawningActor` |
| テクスチャ読み込み | `UKismetRenderingLibrary::ImportFileAsTexture2D(ctx, Filename)`(PNG/JPG直読み) |
| マテリアル | `CreateAndSetMaterialInstanceDynamic` + `SetTextureParameterValue` |
| 補助 | `UKismetProceduralMeshLibrary`(法線/タンジェント計算、StaticMeshからのコピー等) |

構想: コンテンツパックに `models/*.obj`(+PNGテクスチャ)を置く → PalSmithがLua/C++でパースして
頂点配列化 → ProceduralMeshでワールドに生成。**「3Dモデルをきちんとワールドに置ける」**をUE5もpakも
なしで実現する。これが通れば、コミュニティに欠けている「見た目から新しいMod」への最短経路になる。

制約(設計に織り込む):
- **スケルタルメッシュ/アニメーション(=新規Pal本体)は対象外**(そこはcook済みpak+PMKツールチェーンの後続フェーズ)
- ProceduralMeshはNanite/インスタンシング非対応 → 装飾・設備オブジェクト向き。数の上限はF7の診断でガード
- スポーンしたアクターはPalworldのセーブ対象外 → **F4の永続化ストレージに配置情報を記録し、
  ワールドロード時にPalSmithが再生成**(=Behaviorレイヤーのライフサイクル管理と統合)
- レプリケーションされない → 各クライアントのPalSmithがローカル生成(配置データは共有パック+smith://で同期)

検証: **V5**(poc/V5-runtime-mesh)— まず立方体1個をキー入力でプレイヤー前方に生成できるか。

### やらないこと

- **スケルタルメッシュ(新規Palの体)のランタイム読み込み**: AnimBP・スケルトン互換の再実装が必要で
  ABI依存が深すぎる。→ cook済みpakで解く: PMKテンプレプロジェクト+ヘッドレスcook
  (`RunUAT BuildCookRun`)を自動化するCLI(C#、ModManagerの延長)。これは後続フェーズ。

---

## 3. 全体アーキテクチャ

```
PalSmith
├─ ランタイム側: UE4SS C++ (or Lua) Mod — PalSchemaの隣に配置
│   ├─ pack.jsonc の解釈 → PalSchema形式($resource含む)に展開 (レイヤー②③)
│   ├─ Behaviorディスパッチャ+標準ハンドラライブラリ (レイヤー⑥)
│   ├─ ui/*.jsonc の解釈 → 汎用Widget生成・データ流し込み (レイヤー④)
│   └─ アクションレジストリ+イベントバス+チャットプロトコル (レイヤー⑤)
├─ 基底pak: 汎用BP基底クラス+マテリアル (レイヤー①)
│           + 汎用Widgetアーキタイプ WBP_Smith_* (レイヤー④)
├─ 横断基盤: ID名前空間 / 依存解決 / 設定 / 永続化 / ハンドシェイク / 権限 / 診断 (§3.5)
└─ ツール側 (後続): FBX→pak 自動cook CLI (C#)

コンテンツパック = pack.jsonc + ui/*.jsonc + PNG の zip (PalSmithをNexus Requirementに指定)
```

依存スタック: `UE4SS-Palworld` ← `PalSchema` ← `PalSmith` ← 各コンテンツパック

---

## 3.5 横断基盤(基盤Modを「確固たるもの」にする仕組み)

機能レイヤー①〜⑥とは別軸の、長寿命フレームワーク(SMAPI / SKSE+MCM / Minecraft Forge等)が
共通して持つクロスカッティング機能。エコシステムの信頼性はここで決まる。

### F1. ID名前空間とパック規約

- 全コンテンツパックに `packId` を必須化し、アイテム/メニュー/アクションIDは `packId:name` 形式に強制
  (Minecraftの `modid:item` 方式)。**ID衝突はエコシステムが育つほど必ず起きる**ので最初から設計に入れる
- `pack.jsonc` に `formatVersion` / `requiresSmith`(semver範囲)/ `dependencies`(他パック依存)を必須化

### F2. ロード順・依存解決・フェイルソフト

- パック間の依存グラフを解決してロード順を決定(循環はエラー)
- **1つの壊れたパックが他を巻き込まない**: パック単位でtry/catch、失敗パックはスキップして起動継続
- 検証エラーは「どのパックの・どのファイルの・どのキーが悪いか」まで具体的にログ+ゲーム内通知

### F3. 設定システム(Mod Config Menu パターン)

- パックが設定スキーマ(`config.schema.jsonc`)を宣言 → PalSmithが④のUIフレームワークで
  設定画面を自動生成し、値を永続化。SkyUIのMCM / SMAPIのGeneric Mod Config Menuに相当
- **④の最初の実戦投入先(ドッグフーディング)として最適**
- サーバー側設定(ゲームプレイに影響)とクライアント側設定(表示のみ)を明確に区別

### F4. 永続化ストレージAPI

- Modが独自状態を保存する標準手段が現状のPalworldに存在しない → PalSmithが
  **per-player / per-world のKVストア**(サーバー側JSONファイル、プレイヤーUIDキー)を提供
- Behaviorのクールダウン・通貨・クエスト進行・ショップ在庫等、ほぼ全ての「ゲームらしい拡張」の前提
- 書き込みタイミング(即時/定期flush)とバックアップローテーションを最初に決めておく

### F5. サーバー/クライアント ハンドシェイク

- 接続時に `smith://hello`(チャットプロトコル)でバージョン+導入パック一覧を交換
- 不一致の扱いを明文化: PalSmithバージョン不一致=警告、必須パック欠落=機能無効化+ゲーム内通知
- 「サーバーには入っているがクライアントにない」事故はマルチで**必ず起きる**ので、
  無言の挙動不整合ではなく明示的なエラーにする

### F6. 権限と検証(サーバー権威の原則)

- `server_action` / Behavior実行は**クライアントを一切信用しない**: 実行可否は常にサーバー側で判定
  (チャットプロトコルは誰でも偽装送信できる前提で設計)
- ロールベース権限(admin / moderator / player)をアクション定義に宣言 → AdminCommandsの機能を
  この権限システムの上に移植すると自然に統合できる

### F7. アップデート耐性と診断

- ゲームアップデートでフック先が消える前提の設計: 起動時に依存する関数/テーブルの存在チェック
  (feature detection)→ 欠けていたら該当機能だけ無効化+「PalSmithは互換性待ち」バナー
- パック作者向け: 公開JSON Schemaでエディタ補完・検証(PalSchemaと同じ戦略)、
  ゲーム内デバッグオーバーレイ(ロード済みパック/エラー一覧、④で実装)
- 開発体験: `ui/*.jsonc` も自動リロード対象にする

### 優先度の目安

F1・F2は**スキーマ設計の段階で入れないと後から入れられない**(既存パックを壊すため)。
F3〜F5はβ公開まで、F6は `server_action`/Behavior実装と同時(セキュリティなので後回し不可)、F7は継続改善。

---

## 4. Vortex / Nexus 配布

- Nexusに公開し、[Palworld Vortex Extension](https://www.nexusmods.com/site/mods/770) 経由でインストール
- 依存(UE4SS-Palworld版、PalSchema)は Nexus の Requirements 機能で宣言
- コンテンツパックは「JSON+PNGのzip、RequirementにPalSmith」でエコシステム化

### 既知の落とし穴

- [Vortex Issue #17248](https://github.com/Nexus-Mods/Vortex/issues/17248):
  VortexのPalworld拡張は通常版UE4SSを入れてクラッシュさせる問題や、
  Lua Mod配置先(`Pal/Binaries/Win64/Mods`)とPalSchema配下
  (`.../ue4ss/Mods/PalSchema/mods`)の使い分けが不完全な問題がある
- 対策: zipのフォルダルート構造をVortexが正しく展開できる形に設計 + **手動インストール手順を必ず併記**
- Palworld 1.0以降は Steam Workshop 公式対応もあるため、Workshop配布も並行検討可

---

## 5. 前提検証マトリクス(現在地)

**大きなプログラムを書く前に、コンセプトが実証できることを確認する。** 実証すべきコンセプトは次の5つ:

| コンセプト | 意味 | 対応PoC |
|---|---|---|
| C1. アイテムが追加できる | 新アイテム+レシピ+ツリー登録がJSONで成立 | PoC-A |
| C2. リソースが簡単に追加できる | PNG等をpak化なしで取り込める | PoC-A(`$resource`) |
| C3. アイテムがワールド上に配置できる | 「持てる」だけでなく「置ける」、置いた物が機能する | V1 |
| C4. 挙動が保証される | 使用/配置/インタラクト時に独自ロジックを確実に実行できる | V2・V3(+通信路としてPoC-F) |
| C5. UI拡張ができる | メニュー/HUDを追加してプレイヤーが操作できる | V4 |

5つすべてが✅になった時点でPalSmith本体(スキーマ設計→ランタイム実装)に着手する。
リスクの高い順・Behaviorレイヤーの生死に関わるものを最優先。

| # | 内容 | 検証すること | 状態 |
|---|---|---|---|
| PoC-A | PalSchemaのみで新アイテム+レシピ+PNGアイコン+ツリー解放([poc/PoC-A-newcontent](../poc/PoC-A-newcontent)) | データ層をPalSchemaに全委譲できるか / `$resource`が専用鯖+クライアント構成で動くか / `DT_TechnologyRecipeUnlock`のアイテム用列名 | ✅ **クライアント検証成功(2026-07-16)** C1/C2実証。列名`UnlockItemRecipes`確定。残: マルチ構成+セーブ健全性 |
| **V1** | `buildings`+既存BP流用で新規配置物をJSONのみ追加([poc/V1-placeable](../poc/V1-placeable)) | 「配置できるアイテム」がUE5なしで成立するか | ✅ **成功(2026-07-16)** Bメニュー出現・設置・機能OK。C3実証 |
| **V2** | アイテム使用イベントのフック特定([poc/V2-itemuse-hook](../poc/V2-itemuse-hook)) | `onUse` Behaviorの生死。使用時に関数がフックできStaticItemIdが取れるか | ✅ **成功(2026-07-16)** `UseItemToCharacter_ServerInternal`のparam1からID直読み。残: 専用鯖での発火確認 |
| V3 | 配置物イベント(onPlace/onInteract/onCraft)のフック特定 | 建物系Behaviorの成立性 | 未着手(V2の手法を流用) |
| V4 | 最小WBPをcook→BPModLoaderでロード→Luaから開閉+クリック往復 | UIフレームワーク(④)の土台 | 未着手(UE5環境が前提) |
| PoC-F | チャットトランスポート `smith://` の往復+表示抑制([poc/PoC-F-chatprotocol](../poc/PoC-F-chatprotocol)) | `server_action`/ハンドシェイク(F5)の通信路 | スクリプト作成済・実機未検証 |
| **V5** | ProceduralMeshでキー入力から立方体をワールド生成([poc/V5-runtime-mesh](../poc/V5-runtime-mesh)) | ランタイム3Dオブジェクト(⑦)の成立性: AddComponentByClass→CreateMeshSectionのLua呼び出し | ✅ **成功(2026-07-16)** 立方体出現。注意: 空`{}`Transform=スケール0の罠 |
| V6 | LuaからのファイルI/Oで per-player KVストア | 永続化(F4)の成立性(AdminCommandsでini読込実績ありのため低リスク) | 未着手 |

検証がすべて通ったら: `pack.jsonc` / `ui.jsonc` のスキーマ設計(F1/F2を組み込む)→ ランタイム実装へ。

---

## 6. 参考リンク

- [PalSchema — GitHub (Okaetsu/PalSchema)](https://github.com/Okaetsu/PalSchema) ※最新仕様はwebsite/docsを直接見る
- [PalSchema 公式Docs — Getting Started(フォルダ規約)](https://okaetsu.github.io/PalSchema/docs/gettingstarted)
- [PalSchema — Importing Images($resource機能)](https://okaetsu.github.io/PalSchema/docs/) ※repo: website/docs/guides/resources/importingimages.md
- [PalSchema — 新規クラフト台作成ガイド(buildings+Technologyブロック)](https://okaetsu.github.io/PalSchema/docs/) ※repo: website/docs/guides/buildings/craftingstation.md
- [PalworldModdingKit — GitHub (localcc)](https://github.com/localcc/PalworldModdingKit)
- [Palworld Modding Docs — LogicMods (BPModLoader) 入門](https://pwmodding.wiki/docs/developers/ue4ss-modding/logic-mods/introduction)
- [Pal Details UI — Blueprint Code ModのUI実例 (CurseForge)](https://www.curseforge.com/palworld/blueprint-code-mods/pal-details-ui)
- [Palworld Vortex Extension — Nexus](https://www.nexusmods.com/site/mods/770)
- [Vortex Issue #17248 — Palworld特有のUE4SS構成問題](https://github.com/Nexus-Mods/Vortex/issues/17248)
- ローカルナレッジ: `../../__knowledges/palworld-ue4ss-functions.md`(検証済みUE4SS Luaフック集)
