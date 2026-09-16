# rakugo — 落語家の前座数（zenza_count）推計

落語家の **前座修行者数（前座数）** を、各協会の名簿スナップショットから集計し、
名簿の無い年は「二ツ目昇進者数」を proxy に時系列推計する Go モジュール（issue #14）。

## 構成

```
services/rakugo/
├── go.mod
├── embed.go                 # data/rakugo/zenza_counts.json をビルド時に同梱
├── cmd/
│   ├── zenza-count/         # CLI: 名簿を集計し zenza_counts.json を生成
│   └── zenza-server/        # HTTP: GET /rakugo/zenza_counts, GET /healthz
├── internal/zenza/
│   ├── data.go              # Roster/Dataset 型, カウント集計
│   ├── estimate.go          # proxy 推計モデル
│   ├── count_test.go        # 集計テスト
│   ├── estimate_test.go     # モデルテスト
│   └── dataset_test.go      # 出力構造テスト
└── data/rakugo/
    ├── lists/               # 名簿スナップショット (JSON) を配置する場所
    └── zenza_counts.json    # 生成物（コミット済み、embed の入力）
```

## 実行

```bash
cd services/rakugo
go run ./cmd/zenza-count          # lists/ を集計 → data/rakugo/zenza_counts.json
go run ./cmd/zenza-server         # 既定 ADDR=:8080
curl localhost:8080/rakugo/zenza_counts
go test ./...
```

> embed: サーバはコミット済みの `zenza_counts.json` を埋め込むため、ビルド前に
> 一度 `zenza-count` を実行して生成しておく必要がある。

## データ形式

### 名簿（`lists/*.json` — 1団体1年のスナップショット）

```json
{
  "organization": "落語協会",
  "year": 2026,
  "entries": [
    {"name": "○○", "rank": "zenza"},
    {"name": "××", "rank": "futatsume"}
  ],
  "promotions": {"2024": 12, "2025": 10}
}
```

- `rank`: `zenza` / `futatsume` / `shinuchi`。前座数は `zenza` のみを数える。
- `promotions`: 二ツ目昇進者数の年別実績。名簿の無い年の推計用（任意）。
- 追跡団体: 落語協会 / 落語芸術協会 / 上方落語協会 / 落語立川流。

### 生成物（`zenza_counts.json`）

```
meta: 生成時刻 / retention / practice_term_years / method
by_year: [{ year, counts: { 団体名: { year, count, source } } }]
```

- `source`: `roster`（名簿実測）/ `estimate`（proxy 推計）/ `no-data`（未収集）。

## 推計モデル

`promotions[y]` ≒ year `y` に入門した前座の最終数（入門から二ツ目昇進まで
`practice_term_years` 年と仮定）。year `t` の前座数は:

```
count(t) = Σ (t-PracticeTerm < y <= t) promotions[y] × retention^(t-y)
```

- `retention` 既定 0.75（経験則「前座数は四分の三」の検証対象。実測データが集まり次第
  キャリブレーションする。`internal/zenza/estimate.go` を参照）。

## 方針
- 「推測しない」: 実測できない値は `no-data` のまま残し、proxy は明示的に
  `source: "estimate"` として区別する。
- 名簿の最新化は別タスク（issue #12 / #14 のデータ収集を参照）。