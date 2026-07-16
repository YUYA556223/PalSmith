# インストール

## 前提

| 必要なもの | 備考 |
|---|---|
| Palworld (Steam) | クライアント、および(マルチなら)専用サーバー |
| UE4SS (Palworld fork) | **Palworld専用ビルド**が必須。通常版UE4SSはクラッシュします。ゲーム本体のバージョンと世代を合わせること |
| PalSchema **0.5.0+** | 0.6.0推奨。`$resource`によるPNGインポートに必要。UE4SSの世代とペアを合わせる(1月版UE4SS=0.5.x、7月版=0.6.0) |

## PalSmithの導入

### インストーラスクリプト(Windows)

リポジトリのクローンまたはリリースから:

```powershell
.\tools\install.ps1 -GameDir "E:\SteamLibrary\steamapps\common\Palworld" -WithExample
```

UE4SS+PalSchemaの存在を確認し、ランタイムを
`Pal/Binaries/Win64/ue4ss/Mods/PalSmith/` へコピーします。
`-WithExample`でサンプルパックも入ります。

### 手動

1. `src/PalSmith/` を `<game>/Pal/Binaries/Win64/ue4ss/Mods/PalSmith/` へコピー
2. 同フォルダに空の `enabled.txt` があることを確認
3. 必要なら `packs/ExamplePack/` を `.../ue4ss/Mods/PalSchema/mods/` へ

## 動作確認

ゲームを起動し、`Pal/Binaries/Win64/ue4ss/UE4SS.log` を確認:

```
[PalSmith] PalSmith v0.1.0 starting
[PalSmith] pack 'example' v0.1.0 loaded (2 behaviors, 1 meshes) from ExamplePack
[PalSmith] events installed: 4/4 hooks active
[PalSmith] ready
```

サンプルパック導入時は、テクノロジーLv2で**見習いの作業台**/**見習いポーション**を解放して:

- ポーションをクラフト&使用 → アナウンス+木材1個
- 作業台を設置してアクセス → 石の贈り物(クールダウン30秒)+頭上に浮かぶクリスタル

## マルチプレイ

ゲームプレイデータは両側一致が必須です: 専用サーバーと全クライアントに
**PalSmithと同じパック**を入れてください。Behaviorはサーバー権威で実行されます。

> **使い捨てワールドでのテスト推奨。** 不正なアイテムがセーブに入ると
> ワールドがロード不能になり得ます(PalSchemaの警告)。新しいパックは
> 必ず捨てて良いワールドで試してから本番へ。
