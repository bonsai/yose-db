# yose-db

寄席・落語・講談・浪曲などの公演情報を、会場・公演・演者・団体・出典の関係として扱うためのデータベース。

Rails (Ruby) + PostgreSQL (jsonb)。CiNii Research API で講談師の著作を追跡し、BigQuery ML による埋め込み検索にも対応する。

## 二つのデータ層

- **`schema.json` / `ontology.yaml` / `data/*.json`** — 正規スキーマ定義と実データ(初期: **鶴めい七叶亭**・**鶴めいホール**、公式情報由来)
  - `data/venues.json`, `data/event_series.json`
  - エンティティ種別: `venue`(会場) / `event_series`(定例会・シリーズ) / `event`(個別公演) / `performer`(演者) / `organization`(主催・所属団体)
  - 共通フィールド: `id`, `type`, `name`, `sources`
  - 出典: https://nanokatei.official.ec/ , https://kodankyokai.jp/%E3%82%A4%E3%83%99%E3%83%B3%E3%83%88/%E9%B6%B4%E3%82%81%E3%81%84%E4%B8%83%E5%8F%B6%E4%BA%AD%EF%BC%88%E3%81%8B%E3%81%8F%E3%82%81%E3%81%84%E3%80%80%E3%81%AA%E3%81%8B%E3%81%AE%E3%81%A6%E3%81%84%EF%BC%89/
- **Rails API** — PostgreSQL jsonb のスキーマレス ストア (`Yose::Store`) に講談師エントリを保持し、API で検索・参照する

## Rails API

- Ruby 3.3.x / Rails 8.x / PostgreSQL(jsonb・GIN index・moddatetime trigger)
- `lib/yose/store.rb` — psql/jsonb ストア(`alloc` / `alloc!` / `free` / `[]` / `search`(@>) / `update`(||) / `replace` / `delete`(-) / `recent`)
- `lib/cinii/client.rb` + `lib/cinii/json_ld.rb` — CiNii Research OpenSearch (JSON-LD) クライアント (`CINII_APPID` 必須)
- `lib/kodanshi.rb` — 現役講談師名簿(2026年版・123名)のシード登録と CiNii 同期
- `db/seeds/kodanshi_2026.yml` — 名簿データ(5団体 119名 + 無所属 4名)

### API エンドポイント

| Method | Path | 説明 |
|---|---|---|
| GET | `/api/v1/kodanshi` | 名簿一覧 |
| GET | `/api/v1/kodanshi/:uid` | 1件参照 |
| POST | `/api/v1/kodanshi/sync` | CiNii と同期 (`body: {"names":["神田伯山"]}`) |

### セットアップ (WSL / Linux)

```sh
bundle config set --local path vendor/bundle
bundle install
bin/rails db:create db:migrate
bin/rails yose:load_kodanshi   # 名簿123名を登録
CINII_APPID=your_id bin/rails yose:sync_kodanshi  # CiNii 同期
bin/rails test
```

## GitHub Pages (静的API・計算はCI)

`docs/` が GitHub Pages のソース。`bin/rails yose:export_pages` が以下を生成する:

- `docs/data/all_graph.json` — 全講談師の精製グラフ(ノード: 団体/講談師、エッジ: 所属・rank)
- `docs/data/zenza.json` — 前座ランキング(暫定は注目度/話題量 = CiNii 合計ヒット数)

`.github/workflows/pages.yml` が push 時に **CI 内で DB を作り → 名簿を読み → JSON を計算して Pages にデプロイ**する。Pages 設定は Source = GitHub Actions。

- https://bonsai.github.io/yose-db/ (全講談師グラフ)
- https://bonsai.github.io/yose-db/zenza (前座ランキング)

ローカル確認: `python3 -m http.server 8008 --bind 0.0.0.0` を `docs/` で(`scripts/static_pages.sh`)。

## GCP (Cloud Run + Cloud SQL)

`.github/workflows/deploy-gcp.yml` が Workload Identity Federation で Cloud Build → Cloud Run デプロイを行う(手動Trigger、`project_id` を入力)。

### 初回セットアップ(一度だけ)

```bash
# 1) プロジェクトで API を有効化
gcloud services enable run.googleapis.com artifactregistry.googleapis.com \
  builds.googleapis.com cloudbuild.googleapis.com sqladmin.googleapis.com \
  secretmanager.googleapis.com iamcredentials.googleapis.com

# 2) Cloud SQL (PostgreSQL) を作成、DB/user 作成、接続名を控える
gcloud sql instances create yose-db --database-version=POSTGRES_16 \
  --region=asia-northeast1 --tier=db-f1-micro
gcloud sql databases create yose_db --instance=yose-db
gcloud sql users create bons --instance=yose-db --password=...

# 3) シークレット
#   CLOUD_SQL_URL  : postgres://bons:pass@/yose_db?host=/cloudsql/PROJECT:REGION:yose-db
#   RAILS_SECRET_KEY_BASE : bin/rails secret
#   RAILS_MASTER_KEY : config/master.key の内容
#   CINII_APPID    : (任意)
gcloud secrets create cloud_sql_url --data-file=-
gcloud secrets create rails_secret_key_base --data-file=-
# ...

# 4) Workload Identity Federation (GitHub Actions 用)
#    provider 名: projects/PROJECT/locations/global/workloadIdentityPools/github-actions/providers/github
#    サービスアカウントに IAM ロール:
#      Cloud Run デプロイ: roles/run.admin, roles/iam.serviceAccountUser
#      Cloud Build:        roles/cloudbuild.builds.editor
#      Secret 参照:        roles/secretmanager.secretAccessor

# 5) リポジトリの Actions variables/secrets に以下を設定
#     vars:  GCP_WIF_PROVIDER, GCP_SERVICE_ACCOUNT, GCP_REGION, (GCP_REGISTRY=asia-northeast1-docker.pkg.dev/PROJECT/repo)
#     secrets: CLOUD_SQL_URL, RAILS_SECRET_KEY_BASE, RAILS_MASTER_KEY, CINII_APPID, CLOUD_SQL_INSTANCE

# 6) Actions → Deploy to Cloud Run (GCP) → Run workflow (project_id を入力)
```

## BigQuery ML (埋め込み)

講談師エントリのベクトル埋め込みを BigQuery ML で生成し `VECTOR_SEARCH` する構成は実装予定(前座ランキングの6軸評価と連動予定)。詳細は `plan/bqml.md` を参照予定。