# まわる（Mawaru） v0.2 — 交換日記
> 渡すたび、もっと仲良くなる。

iOS 17以降のSwiftUIアプリです。**従来のローカルデモ**と、Firebase接続時に使える**実際の共有日記**の2モードがあります。

## v0.2 の追加機能（サーバー接続後）
- Appleでサインイン（Firebase Authentication / nonce対策済み）
- 2〜5名の共有日記帳、24文字・1回限り・7日間の招待コード
- Cloud Firestore リアルタイム同期（参加者だけ閲覧可能）
- Cloud Functions トランザクションによるバトンの原子的な受け渡し、投稿重複防止
- 文字の日記と端末内の自動下書き。書き終えたら順番が次のユーザーへ進みます
- 日記帳の休止・再開（オーナーのみ）
- GitHub Actions: バックエンド単体テスト + Firebase 13対応Xcodeで未署名IPA作成

**重要:** Firebaseプロジェクトの作成・Apple認証の設定・デプロイはまだ済んでいません。GoogleService-Info.plistがなければ共有タブは案内画面になり、ローカルデモは引き続き動作します。**共有機能はバックエンド配備と認証設定が完了するまで使用できません。**

## 設定
[docs/FIREBASE_SETUP.md](docs/FIREBASE_SETUP.md) を参照。Cloud Functions利用にはFirebase Blazeの請求先設定が必要になる場合があります。
個人情報を含む交換日記を本番公開する前に、ルール検証・エミュレータ統合テスト・監査・アカウント削除・通報・ブロックなどを完成させてください。

## iOSビルド
公開リポジトリのGitHub Actions → **Build unsigned iOS IPA** でビルド。成功時のArtifactsから `Mawaru-unsigned-IPA` ZIPを取得できます。

IPAは**未署名**なので、そのまま端末へインストールできません。適切な証明書で署名してください。アプリ本体のBundle IDは仮の `jp.mawaru.diary` です。

ローカル開発: Xcode 26.2以降 + XcodeGen、`xcodegen generate`。設定ファイルは公開リポジトリへアップロードしないでください。

## まだ未実装
Cloud Storageへの写真保存、プッシュ通知、リアクション同期、退出/削除/通報/ブロック/データエクスポート、課金、タイムカプセル、アクセシビリティの全画面テスト。日記の既存ローカルデータを自動的にクラウドへ移すこともしていません。
