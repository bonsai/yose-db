package zenza

import "testing"

func roster(org string, year int, ranks ...Rank) Roster {
	entries := make([]Entry, 0, len(ranks))
	for _, r := range ranks {
		entries = append(entries, Entry{Name: "m", Rank: r})
	}
	return Roster{Organization: org, Year: year, Entries: entries}
}

func TestCountMapsCountsOnlyZenza(t *testing.T) {
	m := CountMaps([]Roster{
		roster("落語協会", 2026, RankZenza, RankZenza, RankZenza, RankZenza, RankZenza, RankFutatsume, RankShinuchi),
		roster("上方落語協会", 2026, RankZenza, RankZenza, RankZenza),
	})
	kyokai, ok := m[2026]["落語協会"]
	if !ok || kyokai.Count != 5 || kyokai.Source != "roster" {
		t.Fatalf("unexpected 落語協会: %+v ok=%v", kyokai, ok)
	}
	kamigata := m[2026]["上方落語協会"]
	if kamigata.Count != 3 {
		t.Fatalf("unexpected 上方落語協会: %+v", kamigata)
	}
}

func TestCountMapsGroupsByYear(t *testing.T) {
	m := CountMaps([]Roster{
		roster("落語協会", 2025, RankZenza, RankFutatsume),
		roster("落語協会", 2026, RankZenza),
	})
	if m[2025]["落語協会"].Count != 1 || m[2026]["落語協会"].Count != 1 {
		t.Fatalf("year grouping wrong: %+v", m)
	}
}

func TestCountMapsSkipsDeletedRosters(t *testing.T) {
	m := CountMaps(nil)
	if len(m) != 0 {
		t.Fatalf("expected empty map, got %d years", len(m))
	}
}
