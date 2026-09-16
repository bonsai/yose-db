package zenza

import "testing"

func TestBuildDatasetRowsAndSources(t *testing.T) {
	m := CountMaps([]Roster{
		roster("落語協会", 2026, RankZenza, RankZenza),
	})
	d := BuildDataset(m, DefaultEstimator())
	if len(d.ByYear) != 1 || d.ByYear[0].Year != 2026 {
		t.Fatalf("expected one 2026 row, got %+v", d.ByYear)
	}
	agg := d.ByYear[0]
	if agg.Counts["落語協会"].Count != 2 || agg.Counts["落語協会"].Source != "roster" {
		t.Fatalf("roster row wrong: %+v", agg.Counts["落語協会"])
	}
	for _, name := range OrgNames() {
		if name != "落語協会" && agg.Counts[name].Source != "no-data" {
			t.Fatalf("%s should be no-data, got %+v", name, agg.Counts[name])
		}
	}
	if len(agg.Counts) != len(Organizations) {
		t.Fatalf("expected %d orgs, got %d", len(Organizations), len(agg.Counts))
	}
}

func TestBuildDatasetSortsByYear(t *testing.T) {
	rosters := []Roster{
		roster("落語協会", 2026),
		roster("落語協会", 2024),
		roster("落語協会", 2025),
	}
	d := BuildDataset(CountMaps(rosters), DefaultEstimator())
	for i, agg := range d.ByYear {
		want := 2024 + i
		if agg.Year != want {
			t.Fatalf("expected sorted %d at %d, got %d", want, i, agg.Year)
		}
	}
}
