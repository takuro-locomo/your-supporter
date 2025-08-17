# Your Supporter

リハビリテーション支援アプリケーション

## 概要

「Your Supporter」は、手術後のリハビリテーションを支援するFlutterアプリケーションです。患者用モバイルアプリと医療者用Webアプリの2つのエントリポイントを持つデュアルプラットフォーム構成となっています。

## 機能

### 患者用アプリ (main_patient.dart)
- 運動メニューの閲覧と実施
- 動画を見ながらの運動実行
- 運動記録の追跡
- 週間フィードバックの投稿
- 進捗確認

### 医療者用アプリ (main_admin.dart)
- 患者管理
- 運動メニューの作成・編集
- 動画アップロード機能
- フィードバック確認・返信
- 統計ダッシュボード

## 技術スタック

- **Frontend**: Flutter 3.x
- **Backend**: Firebase
  - Authentication (認証)
  - Firestore (データベース)
  - Storage (ファイル保存)
  - Functions (サーバーサイド処理)
- **State Management**: Provider パターン
- **Video Player**: video_player パッケージ
- **File Picker**: file_picker パッケージ

## Firebase Functions

- `createUserDoc`: ユーザー初期化
- `elevateToAdmin`: 管理者権限昇格（招待コード）

## プロジェクト構造

```
lib/
├── firebase_options.dart
├── main_patient.dart          # 患者用エントリポイント
├── main_admin.dart           # 医療者用エントリポイント
├── app_common/               # 共通コード
│   ├── app_theme.dart
│   ├── auth_gate.dart
│   ├── models.dart
│   └── services.dart
├── patient/pages/            # 患者用画面
│   ├── patient_home_page.dart
│   ├── exercise_detail_page.dart
│   └── weekly_feedback_page.dart
└── admin/pages/              # 医療者用画面
    ├── admin_dashboard_page.dart
    ├── exercise_manager_page.dart
    └── patient_editor_page.dart
```

## セットアップ

### 1. 依存関係のインストール
```bash
flutter pub get
```

### 2. Firebase設定
- Firebase プロジェクトを作成
- `flutterfire configure` でプロジェクトを設定
- 必要なFirebaseサービスを有効化

### 3. Functions のデプロイ
```bash
cd functions
npm install
cd ..
firebase deploy --only functions
```

### 4. アプリの起動

患者用アプリ:
```bash
flutter run lib/main_patient.dart
```

医療者用アプリ:
```bash
flutter run lib/main_admin.dart -d chrome
```

## 認証システム

- **患者**: 初期登録時は `patient` ロール
- **管理者**: 招待コードによる昇格システム
- **権限制御**: Firebase Custom Claims + Firestore role

## 開発

### ブランチ戦略
- `main`: 本番環境
- `develop`: 開発環境
- `feature/*`: 機能開発

### コミット規約
- `feat:` 新機能
- `fix:` バグ修正
- `docs:` ドキュメント
- `style:` スタイル修正
- `refactor:` リファクタリング
- `test:` テスト追加
- `chore:` その他

## ライセンス

このプロジェクトは MIT ライセンスの下で公開されています。

## 貢献

1. フォーク
2. フィーチャーブランチを作成 (`git checkout -b feature/AmazingFeature`)
3. コミット (`git commit -m 'Add some AmazingFeature'`)
4. プッシュ (`git push origin feature/AmazingFeature`)
5. プルリクエストを開く
