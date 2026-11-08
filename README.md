# まわる — iOS交換日記アプリ

> 渡すたび、もっと仲良くなる。
>
> 今日の気持ちを、次のページへ。

SwiftUIで作ったiPhone向け交換日記アプリの**ローカル動作デモ（v0.1.0）**です。iOS 17以上を対象としています。

## 現在できること

- 2〜5人の交換日記帳の新規作成と表紙の選択
- 参加者の順番を表示し、書いた日記を次の人へ渡すバトン
- 日記のタイトル・本文・写真1枚の記録
- 下書き自動保存（タイトル・本文）
- 過去ページの閲覧・検索、ハート・お気に入り
- おやすみ・再開、端末内メンバーの切り替え（デモ用）
- 日記本文等のJSONテキストの共有、端末保存データの削除
- ライト・ダークモードの基本対応

## 実装していないこと／注意

**これは単一端末用のデモです。招待コードは表示するだけで、実際の友人に日記を送ることはできません。** Firebase Authentication、Cloud Firestore、Cloud Storage、APNs通知、Sign in with Apple、サーバー側での原子的な投稿制御、課金、通報・ブロック、アカウント管理などは未実装です。個人的な日記を安全に複数端末で共有する本番サービスとして提供しないでください。

写真データはアプリ内のApplication Supportに保存されます。エクスポートされるJSONに写真本体は含まれません。下書きの写真は自動保存対象外です。

## GitHub ActionsでIPAを作る

このリポジトリには `.github/workflows/ios-ipa.yml` があり、mainへのpush・Actionsの手動実行でmacOS標準ランナーを使ったビルドを行います。

1. GitHubの **Actions** → **Build unsigned iOS IPA** を開く。
2. 最新の成功した実行を開く。
3. ページ下部の **Artifacts** → `Mawaru-unsigned-IPA` をダウンロード。
4. ZIPを解凍して `Mawaru-unsigned.ipa` を取り出す。

**未署名IPAは、そのままiPhoneにインストールできません。** iOS実機への導入にはAppleの証明書による署名・プロビジョニングが必要です。App Store/TestFlightに配信するには別途Apple Developer Programなどの準備と審査が必要です。

公開リポジトリで標準GitHub-hosted macOSランナー（`macos-15`）を利用する際は、GitHubの公式ドキュメント上、実行時間は無料の対象です。保存容量や同時実行数などの上限は引き続き適用されます。

## ローカルで開発

macOS + Xcode 16.4 とXcodeGenを用意してください。

```bash
brew install xcodegen
xcodegen generate
open Mawaru.xcodeproj
```

現時点のBundle IDは仮の `jp.mawaru.diary`。公開時は自分のBundle IDに変更してください。

## 次の開発目標

1. Sign in with Apple + Firebase Authentication
2. Firestore・Cloud Storage、厳格なメンバー権限
3. 招待トークン、参加フロー、原子的なバトン更新
4. APNs/FCM通知、通報・ブロック、退会・削除、写真付き完全エクスポート
5. アクセシビリティ、手書き・記念日・タイムカプセル、StoreKit2
6. TestFlightで実機・複数端末テスト

企画日：2026年11月9日 / 事業案：App Store一般公開・基本無料（正式リリースは未実施）。
