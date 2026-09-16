package zenza

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
)

// Rank classes used in roster entries. Only rank "zenza" counts toward the
// zenza-side population.
const (
	RankZenza     = "zenza"
	RankFutatsume = "futatsume"
	RankShinuchi  = "shinuchi"
)

type Rank string

// Roster is one organization's membership snapshot for a single year.
type Roster struct {
	Organization string  `json:"organization"`
	Year         int     `json:"year"`
	Entries      []Entry `json:"entries"`
	// Promotions holds recent futatsume promotion counts by year
	// (e.g. {"2025": 12}). Used by the proxy estimator to backfill years
	// without a roster.
	Promotions map[string]int `json:"promotions,omitempty"`
}

type Entry struct {
	Name string `json:"name"`
	Rank Rank   `json:"rank"`
}

// YearCount is the zenza population for one organization in one year.
type YearCount struct {
	Year  int `json:"year"`
	Count int `json:"count"`
	// Source is "roster" when taken from an actual list, "estimate" when
	// produced by the proxy model.
	Source string `json:"source"`
}

// Organizations is the registry of tracked orgs keyed by display name.
var Organizations = map[string]string{
	"rakugo-kyokai":   "落語協会",
	"rakugo-geijutsu": "落語芸術協会",
	"kamigata":        "上方落語協会",
	"tate-kawa-ryu":   "落語立川流",
}

// OrgNames returns the display names in a stable sorted order.
func OrgNames() []string {
	names := make([]string, 0, len(Organizations))
	for _, n := range Organizations {
		names = append(names, n)
	}
	sort.Strings(names)
	return names
}

// LoadRosters reads every roster JSON under dir and returns them.
func LoadRosters(dir string) ([]Roster, error) {
	files, err := filepath.Glob(filepath.Join(dir, "*.json"))
	if err != nil {
		return nil, err
	}
	sort.Strings(files)
	rosters := make([]Roster, 0, len(files))
	for _, f := range files {
		b, err := os.ReadFile(f)
		if err != nil {
			return nil, err
		}
		var r Roster
		if err := json.Unmarshal(b, &r); err != nil {
			return nil, fmt.Errorf("%s: %w", f, err)
		}
		if r.Year == 0 || r.Organization == "" {
			return nil, fmt.Errorf("%s: roster missing year/organization", f)
		}
		rosters = append(rosters, r)
	}
	return rosters, nil
}

// CountMaps aggregates rosters into (year -> org name -> YearCount).
// Roster counts win over proxies for the same year.
func CountMaps(rosters []Roster) map[int]map[string]YearCount {
	out := map[int]map[string]YearCount{}
	for _, r := range rosters {
		n := 0
		for _, e := range r.Entries {
			if e.Rank == RankZenza {
				n++
			}
		}
		if _, ok := out[r.Year]; !ok {
			out[r.Year] = map[string]YearCount{}
		}
		out[r.Year][r.Organization] = YearCount{Year: r.Year, Count: n, Source: "roster"}
	}
	return out
}

// BuildDataset renders a sorted Dataset. Every tracked org gets a row per
// year (default source "no-data"); roster values override, proxy estimates
// fill orgs that declared promotions for the year.
func BuildDataset(m map[int]map[string]YearCount, est *Estimator) *Dataset {
	years := make([]int, 0, len(m))
	for y := range m {
		years = append(years, y)
	}
	sort.Ints(years)

	set := &Dataset{
		Meta: Meta{
			Retention:    est.Retention,
			PracticeTerm: est.PracticeTerm,
			Method:       "roster + proxy(二ツ目昇進者数 × retention^経過年)",
		},
	}

	for _, y := range years {
		agg := YearAggregate{Year: y, Counts: map[string]YearCount{}}
		for _, name := range OrgNames() {
			agg.Counts[name] = YearCount{Year: y, Count: 0, Source: "no-data"}
		}
		for name, yc := range m[y] {
			agg.Counts[name] = yc
		}
		set.ByYear = append(set.ByYear, agg)
	}
	return set
}

// Dataset is the generated zenza_counts document.
type Dataset struct {
	Meta   Meta            `json:"meta"`
	ByYear []YearAggregate `json:"by_year"`
}

type Meta struct {
	GeneratedAt  string  `json:"generated_at"`
	Retention    float64 `json:"retention"`
	PracticeTerm int     `json:"practice_term_years"`
	Method       string  `json:"method"`
}

type YearAggregate struct {
	Year   int                  `json:"year"`
	Counts map[string]YearCount `json:"counts"`
}
