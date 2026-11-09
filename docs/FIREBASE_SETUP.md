# Firebaseで2台のiPhoneをつなぐ手順（v0.2）
ここは実運用向けの設定手順です。GitHubが公開リポジトリなので、**Apple秘密鍵、サービスアカウント鍵、署名証明書等をcommitしないこと。**

1. [Firebase Console](https://console.firebase.google.com/)でプロジェクトを作成し、Firestore（production mode）とAuthenticationを有効化する。Functionsはリージョン `asia-northeast1` を使います。
2. Authentication のログイン方法で **Apple** を有効にする。Apple Developer側でApp IDの「Sign in with Apple」権限、必要なService ID/鍵/Team IDを設定する。iOSで使う `jp.mawaru.diary` は仮のBundle IDなので、本番は管理可能な固有IDに変更してください。
3. Firebase ConsoleでiOSアプリ（上で決めたBundle ID）を登録し、`GoogleService-Info.plist` を取得して **`Mawaru/GoogleService-Info.plist`** に配置。絶対に鍵類を含むファイルをGitHubへ上げないこと（このファイルはgitignore対象）。Firebase設定値自体はクライアントに含まれるものですが、公開リポジトリに個別環境設定を紐づけない方針です。
4. ローカルで `npm install -g firebase-tools`、`firebase login`、`firebase use --add` からプロジェクトを紐付けます。`firebase deploy --only firestore:rules,functions` を実行します。Cloud Functions (2nd gen) を利用するため、プロジェクトにBlazeの支払い設定が必要になる場合があります。
5. Firebase Emulator Suiteで、未認証・非メンバーの読込拒否、招待の1回使用、競合投稿時の片方拒否、連続投稿拒否を**実機前に統合テスト**してください。本リポジトリの `node --test` は入力検証とバトン演算の単体テストのみで、Firebase環境を用いた統合テストではありません。
6. Xcode 26.2以降とXcodeGenで `xcodegen generate` し、Apple Developerの署名で実機にインストール。Appleでサインイン→共有日記作成→招待コードを相手に送信→相手が参加→交互に投稿できるか確認します。

## データモデルと安全性
- `notebooks/{id}`: `memberIds` `memberNames` `currentTurn` `ownerId` `paused` など。Firestoreはメンバーだけが取得/クエリ可能。
- `notebooks/{id}/entries/{id}`: 投稿本文、作成者、連番。読み取りはメンバー限定。
- `invites/{sha256(code)}`: トークンのハッシュと利用者/期限。クライアントから直接読むことは不可。
- **更新はすべてcallable Cloud Functions経由**で行い、Firestoreの端末からの書込みは禁止。Functionsは管理者権限で動くため、認証・メンバー確認・長さ制限・トランザクションをコードで行っています。
- Cloud Functionsの例には呼び出しレート制限・App Check強制・本番監視はまだないため、公開前に追加してください。
- 現バージョンはE2EEではありません。Firebase管理者やサーバーは本文を扱えます。センシティブな本番利用は正式監査後にしてください。
- 招待は1件につき1ユーザー、発行から7日間、ランダム96ビット。コードは日記帳のメンバーだけが発行できます。再利用・期限切れは拒否されます。
- クラウド機能にはアカウント削除、データ削除、通報・ブロック、写真、通知はまだありません。App Store一般公開に移行する前の必須タスクです。
- 既存のローカル日記は本バージョンでは移行されません。共有タブに自動投稿しないので、知らないうちにアップロードされることはありません。

## Actionsについて
`ios-ipa.yml` はデモの継続利用を守るため、Firebase設定ファイルなしでもコンパイルして未署名IPAを生成します。
本番Firebaseに接続したIPAが必要なら、配置/署名方法を別途安全に設計してください。**Firebase認証・BackendのデプロイはGitHub Actionsに任せていません。**
