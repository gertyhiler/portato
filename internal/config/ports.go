package config

import (
	"strconv"
	"strings"
)

// LocalPort extracts the integer port from a local address in any of the
// forms Tuber.ListenAddr accepts: a bare port ("5432"), ":port", or
// "host:port" (including "[::1]:port"). ok is false when there is no
// parseable port. Port 0 is reported as (0, true) — the caller decides
// whether an ephemeral bind is allowed.
func LocalPort(local string) (port int, ok bool) {
	s := strings.TrimSpace(local)
	if s == "" {
		return 0, false
	}
	if p, err := strconv.Atoi(s); err == nil {
		return p, true
	}
	i := strings.LastIndex(s, ":")
	if i < 0 {
		return 0, false
	}
	p, err := strconv.Atoi(s[i+1:])
	if err != nil {
		return 0, false
	}
	return p, true
}

// UsedLocalPorts collects the parsed local ports of every tuber (unparseable
// ports are skipped). The duplicate's bumped port avoids these — config-level
// collisions only; no OS-level probe (that is the dialer's job).
func UsedLocalPorts(tubers []Tuber) map[int]bool {
	used := make(map[int]bool)
	for _, t := range tubers {
		if p, ok := LocalPort(t.Local); ok {
			used[p] = true
		}
	}
	return used
}

// BumpLocalPort increments the port in a local address until it does not
// collide with any port in used, preserving the address format: a bare port
// ("5432") stays bare, ":port" keeps its wildcard host, and "host:port"
// keeps its host. Addresses without a parseable port are returned unchanged.
// Phase 39, F13 follow-up: a duplicated tuber inherits the source's local
// port, so without a bump the duplicate is a guaranteed listen conflict.
// Phase 56: lifted from the TUI so the CLI and engine share one
// implementation.
func BumpLocalPort(local string, used map[int]bool) string {
	s := strings.TrimSpace(local)
	port, ok := LocalPort(s)
	if !ok {
		return local
	}
	for used[port] {
		port++
	}
	if _, err := strconv.Atoi(s); err == nil {
		return strconv.Itoa(port)
	}
	i := strings.LastIndex(s, ":")
	return s[:i] + ":" + strconv.Itoa(port)
}
