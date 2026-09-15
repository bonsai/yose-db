# yose-db

寄席・落語・講談・浪曲などの公演情報を、会場・公演・演者・団体・出典の関係として扱うためのデータベース。

## Current schema

`schema.json` が現在の正規スキーマです。

主なエンティティ種別:

- `venue` — 会場
- `event_series` — 定例会・シリーズ
- `event` — 個別公演
- `performer` — 演者
- `organization` — 主催・所属団体

共通の基本フィールドは `id`, `type`, `name`, `sources`。会場は `address`, `telephone`、公演・シリーズは `venue_id`, `performer_ids`, `organization_ids`, `ticket`, `schedule` などで関係を表現する。

## Real data

初期データとして、公式情報をもとに **鶴めい七叶亭** と **鶴めいホール** を登録している。

- `data/venues.json`
- `data/event_series.json`

### Sources

- https://nanokatei.official.ec/
- https://kodankyokai.jp/%E3%82%A4%E3%83%99%E3%83%B3%E3%83%88/%E9%B6%B4%E3%82%81%E3%81%84%E4%B8%83%E5%8F%B6%E4%BA%AD%EF%BC%88%E3%81%8B%E3%81%8F%E3%82%81%E3%81%84%E3%80%80%E3%81%AA%E3%81%8B%E3%81%AE%E3%81%A6%E3%81%84%EF%BC%89/

Official site states that 鶴めい七叶亭 is held at 鶴めいホール in 飯田橋, with one-day/three-performer programming across seven days each month, featuring 21 shin'uchi performers under 30 years of professional experience. The September 2026 first-anniversary special program lists a 3,000-yen admission and 2,500-yen student price.
