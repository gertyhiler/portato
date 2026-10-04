package config

import "testing"

// TestBumpLocalPort pins the Phase 39 auto-bump (Phase 56: lifted from the
// TUI unchanged): a duplicated tuber's local port is bumped past every port
// already used in the config (config-level only, no OS probe), preserving
// the address format (bare port, ":port", "host:port", IPv6 host).
func TestBumpLocalPort(t *testing.T) {
	used := map[int]bool{5432: true, 5433: true, 8080: true}
	cases := []struct {
		name  string
		local string
		want  string
	}{
		{"bare port bumped past the used run", "5432", "5434"},
		{"bare port free stays", "9000", "9000"},
		{"host:port preserves host", "127.0.0.1:5432", "127.0.0.1:5434"},
		{":port keeps wildcard form", ":8080", ":8081"},
		{"ipv6 host preserved", "[::1]:5432", "[::1]:5434"},
		{"no port unchanged", "localhost", "localhost"},
		{"empty unchanged", "", ""},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			if got := BumpLocalPort(c.local, used); got != c.want {
				t.Errorf("BumpLocalPort(%q) = %q, want %q", c.local, got, c.want)
			}
		})
	}
}

// TestUsedLocalPorts pins that the collision set is gathered across every
// local address form (bare, host:port, :port), skipping unparseable ones.
func TestUsedLocalPorts(t *testing.T) {
	tubers := []Tuber{
		{Name: "a", Local: "5432"},           // bare
		{Name: "b", Local: "127.0.0.1:8080"}, // host:port
		{Name: "c", Local: ":9000"},          // wildcard
		{Name: "d", Local: "bad"},            // unparseable -> skipped
	}
	got := UsedLocalPorts(tubers)
	if !got[5432] || !got[8080] || !got[9000] {
		t.Errorf("UsedLocalPorts = %v, want 5432/8080/9000 present", got)
	}
	if len(got) != 3 {
		t.Errorf("UsedLocalPorts len = %d, want 3 (unparseable skipped)", len(got))
	}
}

// TestLocalPortZero pins the Phase 56 ephemeral semantics: port 0 parses as
// a valid port (the caller decides whether an ephemeral bind is allowed).
func TestLocalPortZero(t *testing.T) {
	if p, ok := LocalPort("0"); !ok || p != 0 {
		t.Errorf(`LocalPort("0") = %d, %v; want 0, true`, p, ok)
	}
	if p, ok := LocalPort("127.0.0.1:0"); !ok || p != 0 {
		t.Errorf(`LocalPort("127.0.0.1:0") = %d, %v; want 0, true`, p, ok)
	}
}
