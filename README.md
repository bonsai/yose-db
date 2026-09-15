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

## BigQuery ML (埋め込み検索)

講談師エントリのベクトル埋め込みを BigQuery ML で生成し、`VECTOR_SEARCH` による KNN セマンティック検索を行う(実装中。`app/lib/bigquery/` 参照)。