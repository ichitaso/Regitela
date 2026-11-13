<p align="center">
  <img src="Regitela/Assets.xcassets/AppIcon.appiconset/AppIcon.png" width="128" alt="Regitela アイコン">
</p>

<h1 align="center">Regitela</h1>

<p align="center">
  <a href="https://github.com/forcequitOS/worse_query">worse_query</a> のサンドボックス脱出を利用した、iOS 向けのファイルエクスプローラー兼 Tweak ツールです。
</p>

## インストール

> [!IMPORTANT]
> **IPA は [Impactor](https://github.com/claration/impactor/releases) でインストールしてください。Sideloadly でインストールすると Regitela は動作しません。**
>
> Regitela が worse_query を使うには App Group の entitlement が必要です。Sideloadly はこれを外して署名するため、「no accessible app group」や「Couldn't get access to the container」のエラーで全機能が動きません。Impactor は App Group を残したまま署名します。

1. [Releases](../../releases) ページから `Regitela_<version>.ipa` をダウンロードします。
2. [Impactor](https://github.com/claration/impactor/releases) でインストールします。
3. Regitela を開きます。ログタブに `app group: none` と表示された場合は、署名の際に App Group が外れています。Impactor でインストールし直してください。

## ご利用の前に

> [!WARNING]
> **Regitela の使用は自己責任でお願いします。** 通常 iOS が触らせないファイルを編集するため、誤った編集でアプリや iOS が正常に動作しなくなることがあります。**必ず事前に端末のバックアップを取ってください。** 開発者は、いかなる損害やデータの損失についても責任を負いません。

> [!CAUTION]
> すでに MDM で管理されている端末では、監視モードを有効にしないでください。

## 機能

- **監視モード**: オン・オフを切り替えます。設定アプリを終了すると反映されます。
- **地域**: MobileGestalt キャッシュの地域コードと販売地域を、一覧から選んだ地域に変更します（既定は US (LL/A)。ほかに JP、CN、HK、TW、KR、GB、DE、FR、CA、AU、SG、IN、VN）。再起動で反映され、その後の再起動でも元に戻りません。元の値はバックアップされ、復元できます。
- **充電上限**: 充電上限に対応していない機種で、設定 > バッテリー > 充電 に充電上限の項目を追加します。再起動で反映されます。実際に上限で充電が止まるかは機種によります。
- **常時表示**: 設定 > 画面表示と明るさ に常時表示を追加します。再起動で反映されます。低いリフレッシュレートに下げられない画面では、バッテリーの消費が大きく増え、焼き付きのおそれもあります。
- **タップでスリープ解除**: 対応していない機種で、設定 > アクセシビリティ > タッチ にタップでスリープ解除を追加します。再起動で反映されます。
- **ブラウズ**: App Group とシステムのコンテナを直接開きます。テキストファイルの編集・保存、新規作成、ファイルの削除ができます。長押しで名前変更・コピー・移動・圧縮・共有、zip ファイルの展開ができます。アプリのフォルダにはアプリのアイコンが表示され、検索バーで一覧を絞り込めます。
- **コンテナ**: pathleak でアプリ、拡張機能、システムサービスのコンテナを探します。アプリ名またはバンドル ID で一覧表示され、どれでも開けます。
- **詳細**: 任意のパスに使える、オリジナルの worse_query ツールです。サンドボックス拡張の保持、パスの内容の共有、パス以下のフォルダの一覧表示ができます。
- Liquid Glass の UI、17言語に対応。

## 対応バージョン

| インストール方法 | iOS | 備考 |
|---|---|---|
| IPA（サイドロード） | 26.0 - 26.7.2、27.0 - 27.2 | Tweak とブラウズには iOS 27 が必要 |

> [!NOTE]
> 記載のないバージョンには対応していません。今後の iOS アップデートで worse_query が修正される可能性があります。

## ビルド

[Theos](https://theos.dev) と Xcode 26 が必要です。

```sh
make package
```

このコマンドで、IPA と rootless 用の .deb の両方が `packages/` に作成されます。

一覧にない地域を追加したい場合は、`Regitela/Region.swift` の `targetRegions` に項目（ISO 国コードと地域コード。例: 日本は `JP` と `J`）を追加してビルドしてください。販売地域（RegionInfo）は、端末にすでにあるキーだけを書き換えます。iOS 27 では存在しないキーを追加すると、次の起動時に iOS がキャッシュを作り直してしまいます。

## よくある質問

1. **何も動作せず、ログタブに「no accessible app group」と表示される。**
   App Group なしで署名されています。Sideloadly でインストールするとこうなります。[Impactor](https://github.com/claration/impactor/releases) でインストールし直してください。
2. **Xcode でビルドしたら「Couldn't get access to the container (handle -1)」と表示される。**
   Xcode で署名する際に App Group が含まれていません。Signing & Capabilities で自分のチームに登録した App Group を追加してチェックを入れ、ビルドし直してください。Regitela は entitlements からグループ名を読み取るので、名前は何でも構いません。ログタブに `app group: <グループ名>` と表示されれば正常です。
3. **iOS 26 で Tweak やブラウズが動作しない。**
   これらには iOS 27 が必要です。iOS 26 では、worse_query で SystemGroup のコンテナにアクセスできません。
4. **コンテナのスキャンに時間がかかる。**
   pathleak は inode を総当たりで調べるため、初回のスキャンには時間がかかります。結果はアプリを終了するまで保持されます。
5. **アプリ名ではなくバンドル ID で表示されるコンテナがある。**
   サンドボックス内のアプリには、iOS が一部のアプリの名前しか教えないためです。
6. **ログタブには何が表示される？**
   アプリが何をしているか、何かが失敗した理由が表示されます。テキストを長押しするとコピーできます。

## クレジット

- [ichitaso](https://github.com/ichitaso): Regitela
- [forcequit (Taj C)](https://github.com/forcequitOS): [worse_query](https://github.com/forcequitOS/worse_query) と pathleak。Regitela は worse_query をベースにしています。

## ライセンス

Regitela は worse_query と同じ [GPL-3.0](LICENSE) でライセンスされています。
