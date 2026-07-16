# V2: アイテム使用イベントのフック特定(Behaviorレイヤーの生死を分ける)

**目的**: 「アイテムを使った」瞬間をLuaでフックし、**どのアイテムか(StaticItemId)を特定できる**ことを
確認する。これが取れれば `onUse` Behavior が成立し、PalSmithの中核構想が確定する。

## 手順

1. まず候補関数を洗い出す:
   - zDev UE4SS でCXXヘッダをダンプ(`__knowledges/palworld-ue4ss-functions.md` の手順)
   - `Pal.hpp` を `UseItem|UseFood|Consume|RequestUse` あたりでgrep
   - または Live View を開いてアイテムを使用し、直後のオブジェクト/関数呼び出しを観察
2. 見つけた候補を `src/server/Scripts/main.lua` の `CANDIDATES` に追記
3. このModをサーバー(まずはローカルクライアントでも可)の
   `Pal/Binaries/Win64/ue4ss/Mods/PalSmithV2Probe/` として配置し、`mods.txt`(または enabled.txt)で有効化
4. ゲーム内で回復薬・食べ物・スフィア等を使用し、ログ(`UE4SS.log`)で
   `[SmithV2] FIRED:` 行を確認
5. 発火した関数のパラメータからアイテムIDが取れるか確認(スクリプトが型と値をダンプする)

## 判定

- ✅ 使用時に発火し StaticItemId が取れる → onUse Behavior確定。plan.md §2⑥ を「検証済み」に更新
- 🔶 発火するがIDが直接取れない → self(インベントリ/スロット)からの逆引きを調査
- ❌ 専用サーバーで発火しない → クライアント側フック+smith://で通知する構成に変更(PoC-Fと合流)

## 結果記録

(実施後にここへ: 発火した関数パス / パラメータ構造 / サーバー・クライアント別の挙動)
