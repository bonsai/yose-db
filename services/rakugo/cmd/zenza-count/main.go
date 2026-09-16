package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"time"

	zenza "github.com/bonsai/yose-db/services/rakugo/internal/zenza"
)

// zenza-count regenerates data/rakugo/zenza_counts.json from the roster
// snapshots in data/rakugo/lists/.
//
// Usage (from services/rakugo):
//
//	go run ./cmd/zenza-count
func main() {
	dir := flag.String("dir", "./data/rakugo", "module data directory (contains lists/ and the output zenza_counts.json)")
	flag.Parse()
	if err := run(*dir); err != nil {
		fmt.Fprintln(os.Stderr, "zenza-count:", err)
		os.Exit(1)
	}
}

func run(dir string) error {
	rosters, err := zenza.LoadRosters(filepath.Join(dir, "lists"))
	if err != nil {
		return err
	}

	est := zenza.DefaultEstimator()
	counts := zenza.CountMaps(rosters)

	// Fill proxy estimates: for each roster carrying promotions, backfill every
	// year in the promotion span that lacks an actual roster.
	for _, r := range rosters {
		years := promoYears(r.Promotions)
		if len(years) == 0 {
			continue
		}
		for _, y := range years {
			if _, ok := counts[y][r.Organization]; ok {
				continue // actual roster wins
			}
			n, ok := est.Estimate(y, r.Promotions)
			if !ok {
				continue
			}
			if counts[y] == nil {
				counts[y] = map[string]zenza.YearCount{}
			}
			counts[y][r.Organization] = zenza.YearCount{Year: y, Count: n, Source: "estimate"}
		}
	}

	d := zenza.BuildDataset(counts, est)
	if len(counts) == 0 {
		// No rosters yet: emit a current-year row so the JSON shape stays
		// documented ("no-data" for every org).
		counts[time.Now().UTC().Year()] = map[string]zenza.YearCount{}
		d = zenza.BuildDataset(counts, est)
	}
	d.Meta.GeneratedAt = time.Now().UTC().Format(time.RFC3339)
	d.Meta.Method = fmt.Sprintf("roster(%d) + proxy", len(rosters))

	b, err := json.MarshalIndent(d, "", "  ")
	if err != nil {
		return err
	}
	out := filepath.Join(dir, "zenza_counts.json")
	if err := os.WriteFile(out, append(b, '\n'), 0o644); err != nil {
		return err
	}
	fmt.Fprintln(os.Stderr, "wrote", out)
	return nil
}

func promoYears(p map[string]int) []int {
	ys := make([]int, 0, len(p))
	for k := range p {
		y, err := strconv.Atoi(k)
		if err != nil {
			continue
		}
		ys = append(ys, y)
	}
	sort.Ints(ys)
	return ys
}
