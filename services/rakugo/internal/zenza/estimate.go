package zenza

import (
	"math"
	"sort"
	"strconv"
)

// Estimator backfills zenza population for years without an actual roster
// using futatsume promotion counts as a proxy.
//
// Model:
//
//	promotions[y] ≈ new zenza entrants who entered in year y (an entrant is
//	promoted to futatsume after `PracticeTerm` years, so the cohort entering in
//	y is promoted around y+PracticeTerm — the roster of promotions therefore
//	tells us the final population of each entry cohort).
//
// Zenza population at year t is then:
//
//	count(t) = Σ_{y in [t-PracticeTerm+1, t]} promotions[y] × Retention^(t-y)
//
// Retention (default 0.75) models members who leave before reaching the next
// stage ("前座数は四分の三" 経験則として検証対象にするパラメータ。実測で随時
// キャリブレーションする想定).
type Estimator struct {
	Retention    float64
	PracticeTerm int
}

// DefaultEstimator is the out-of-the-box model.
func DefaultEstimator() *Estimator {
	return &Estimator{Retention: 0.75, PracticeTerm: 3}
}

// Estimate returns the model population for year t from a promotion map.
func (e *Estimator) Estimate(year int, promotions map[string]int) (int, bool) {
	if e.Retention <= 0 || e.Retention > 1 || e.PracticeTerm <= 0 {
		return 0, false
	}
	// Promotions may be keyed by string (JSON). Parse them once, sorted.
	entries := make([]promo, 0, len(promotions))
	for k, v := range promotions {
		y, err := strconv.Atoi(k)
		if err != nil {
			continue
		}
		entries = append(entries, promo{year: y, count: v})
	}
	sort.Slice(entries, func(i, j int) bool { return entries[i].year < entries[j].year })

	total := 0.0
	seen := false
	for _, p := range entries {
		age := year - p.year
		if age < 0 || age >= e.PracticeTerm {
			continue
		}
		factor := math.Pow(e.Retention, float64(age))
		total += float64(p.count) * factor
		seen = true
	}
	if !seen {
		return 0, false
	}
	return int(math.Round(total)), true
}

type promo struct {
	year  int
	count int
}
