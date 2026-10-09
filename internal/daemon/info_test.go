//go:build unix

package daemon

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"
)

func TestInfoRequiresAuthenticationAndResolvesConfigPath(t *testing.T) {
	s := &Server{cfgPath: "custom.yaml", token: "test-token"}
	request := httptest.NewRequest(http.MethodGet, "/info", nil)
	denied := httptest.NewRecorder()
	s.routes().ServeHTTP(denied, request)
	if denied.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d", denied.Code)
	}
	request.Header.Set("Authorization", "Bearer test-token")
	response := httptest.NewRecorder()
	s.routes().ServeHTTP(response, request)
	if response.Code != http.StatusOK {
		t.Fatalf("status = %d: %s", response.Code, response.Body)
	}
	var result struct {
		Protocol   int    `json:"protocol"`
		ConfigPath string `json:"config_path"`
	}
	if err := json.Unmarshal(response.Body.Bytes(), &result); err != nil {
		t.Fatal(err)
	}
	expected, err := filepath.Abs("custom.yaml")
	if err != nil {
		t.Fatal(err)
	}
	if result.Protocol != 1 || result.ConfigPath != expected {
		t.Fatalf("info = %+v", result)
	}
}

func TestInfoExpandsHomeConfigPath(t *testing.T) {
	home, err := os.UserHomeDir()
	if err != nil {
		t.Fatal(err)
	}
	s := &Server{cfgPath: "~/.config/portato/config.yaml"}
	response := httptest.NewRecorder()
	s.handleInfo(response, httptest.NewRequest(http.MethodGet, "/info", nil))
	var result struct {
		ConfigPath string `json:"config_path"`
	}
	if err := json.Unmarshal(response.Body.Bytes(), &result); err != nil {
		t.Fatal(err)
	}
	if result.ConfigPath != filepath.Join(home, ".config/portato/config.yaml") {
		t.Fatalf("config path = %q", result.ConfigPath)
	}
}
