package forward

import (
	"context"
	"strconv"
	"strings"
	"testing"

	"github.com/portuber/portato/internal/config"
)

// TestEngineEnable_PreflightNamesConflict pins the Phase 56 DoD: enabling a
// tuber whose local port is held by another tuber's live listener fails fast
// with the conflict named, and the tuber is never started.
func TestEngineEnable_PreflightNamesConflict(t *testing.T) {
	a := tuberCfg("a") // local: 10000
	b := tuberCfg("b")
	b.Local = "10000"
	cfg := &config.Config{Tubers: []config.Tuber{a, b}}
	e, fakes := newTestEngine(cfg)
	fakes["a"].livePort = 10000 // a's listener is live

	err := e.Enable("b")
	if err == nil {
		t.Fatal("enable on a held port must fail")
	}
	if !strings.Contains(err.Error(), `"a"`) || !strings.Contains(err.Error(), "10000") {
		t.Errorf("error must name the conflict (port + tuber), got: %v", err)
	}
	if fakes["b"].starts.Load() != 0 {
		t.Error("Start must not be called after a preflight failure")
	}
}

// TestEngineEnable_PreflightPassesEphemeralAndDistinct pins that local: 0
// skips the preflight (the OS assigns a free port) and that a non-conflicting
// port enables normally.
func TestEngineEnable_PreflightPassesEphemeralAndDistinct(t *testing.T) {
	a := tuberCfg("a")
	z := tuberCfg("z")
	z.Local = "0"
	cfg := &config.Config{Tubers: []config.Tuber{a, z}}
	e, fakes := newTestEngine(cfg)
	fakes["a"].livePort = 10000

	if err := e.Enable("z"); err != nil {
		t.Fatalf("ephemeral local: 0 must pass preflight: %v", err)
	}
	if fakes["z"].starts.Load() != 1 {
		t.Error("ephemeral tuber must start")
	}
	// The holder itself re-enables fine (its own port is excluded).
	if err := e.Enable("a"); err != nil {
		t.Fatalf("own port must not conflict: %v", err)
	}
}

// TestEngineEnable_PreflightIgnoresRemote pins that type=remote tubers (no
// local listener) skip the preflight entirely.
func TestEngineEnable_PreflightIgnoresRemote(t *testing.T) {
	a := tuberCfg("a")
	r := tuberCfg("r")
	r.Type = "remote"
	r.Local = "10000"
	cfg := &config.Config{Tubers: []config.Tuber{a, r}}
	e, fakes := newTestEngine(cfg)
	fakes["a"].livePort = 10000

	if err := e.Enable("r"); err != nil {
		t.Fatalf("remote type must skip the preflight: %v", err)
	}
	if fakes["r"].starts.Load() != 1 {
		t.Error("remote tuber must start")
	}
}

// TestTuberStatusLocalReportsBoundPort pins the Phase 56 DoD for local: 0:
// Start binds synchronously (even though the SSH dial fails without a
// server), Status().Local must report the actual bound port — and two
// local: 0 tubers must hold distinct ports.
func TestTuberStatusLocalReportsBoundPort(t *testing.T) {
	newTuber := func(name string) *Tuber {
		cfg := tuberCfg(name)
		cfg.Local = "0"
		return NewTuber(context.Background(), cfg, config.Defaults{}, nil, nil, nil)
	}
	t1, t2 := newTuber("t1"), newTuber("t2")
	defer t1.Stop()
	defer t2.Stop()

	if err := t1.Start(context.Background()); err != nil {
		t.Fatalf("Start t1: %v", err)
	}
	if err := t2.Start(context.Background()); err != nil {
		t.Fatalf("Start t2: %v", err)
	}
	p1, ok1 := t1.LiveLocalPort()
	p2, ok2 := t2.LiveLocalPort()
	if !ok1 || !ok2 {
		t.Fatalf("live ports not reported: %d %v / %d %v", p1, ok1, p2, ok2)
	}
	if p1 == p2 {
		t.Errorf("two local: 0 tubers share port %d", p1)
	}
	if got := t1.Status().Local; !strings.HasSuffix(got, ":"+strconv.Itoa(p1)) {
		t.Errorf("Status().Local = %q, want suffix :%d", got, p1)
	}
}
