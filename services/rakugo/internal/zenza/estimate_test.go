package zenza

import (
	"strconv"
	"testing"
)

func promotions(pairs map[int]int) map[string]int {
	m := map[string]int{}
	for y, n := range pairs {
		m[strconv.Itoa(y)] = n
	}
	return m
}

func TestEstimateAgesOutAfterTerm(t *testing.T) {
	e := &Estimator{Retention: 0.75, PracticeTerm: 3}
	got, ok := e.Estimate(2026, promotions(map[int]int{2024: 10}))
	if !ok || got != 6 { // 10 × 0.75² = 5.625 → 6
		t.Fatalf("expected 6, got %d (ok=%v)", got, ok)
	}
}

func TestEstimateFirstYearIsFull(t *testing.T) {
	e := &Estimator{Retention: 1.0, PracticeTerm: 3}
	got, ok := e.Estimate(2024, promotions(map[int]int{2024: 10}))
	if !ok || got != 10 {
		t.Fatalf("expected 10, got %d (ok=%v)", got, ok)
	}
}

func TestEstimateIgnoresOldCohorts(t *testing.T) {
	e := &Estimator{Retention: 0.75, PracticeTerm: 3}
	got, ok := e.Estimate(2026, promotions(map[int]int{2020: 10}))
	if ok {
		t.Fatalf("expected no estimate for aged-out cohort, got %d", got)
	}
	if got != 0 {
		t.Fatalf("expected 0 on miss, got %d", got)
	}
}

func TestEstimateUnknownYearKeysIgnored(t *testing.T) {
	e := &Estimator{Retention: 0.75, PracticeTerm: 3}
	got, ok := e.Estimate(2026, promotions(map[int]int{2025: 4}))
	if !ok || got != 3 { // 4 × 0.75 = 3.0
		t.Fatalf("expected 3, got %d (ok=%v)", got, ok)
	}
}
