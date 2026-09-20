package tui

import (
	"fmt"
	"strings"

	"charm.land/bubbles/v2/textinput"
	tea "charm.land/bubbletea/v2"
	"charm.land/lipgloss/v2"
	"github.com/portuber/portato/internal/config"
	"github.com/portuber/portato/internal/controller"
)

// tuberEditor is the Phase 10 form for creating/editing a tuber. It is the
// first sub-model in the TUI: the main Model holds a *tuberEditor (nil when
// inactive) and routes keys to it while it is open.
//
// The form overlays its inputs on src (the tuber the editor was opened on),
// so any config field without a form input survives the save by construction
// (Phase 52). Enabled is carried through unchanged from the edited tuber (or
// false for a new one) — it stays controlled by the space toggle in the list.
type tuberEditor struct {
	mode     editorMode
	original string       // name being edited ("" for new); used for rename + uniqueness
	src      config.Tuber // the source tuber; non-form fields survive the save via overlay
	enabled  bool         // preserved from the edited tuber
	pal      palette      // resolved styles (Phase 37); Model overrides at open time

	name       textinput.Model
	ssh        textinput.Model
	local      textinput.Model
	remote     textinput.Model
	identity   textinput.Model
	jump       textinput.Model
	socks5User textinput.Model
	socks5Pass textinput.Model
	tags       textinput.Model

	typeIdx         int // index into tuberTypes
	passwordAuthIdx int // index into passwordAuthStates

	focus  int
	width  int
	height int

	existing []string // current tuber names, for uniqueness
	ctrl     controller.Controller

	errs   map[string]string
	status string

	saved bool
	done  bool
}

type editorMode int

const (
	modeEdit editorMode = iota
	modeNew
)

var tuberTypes = []string{"local", "remote", "dynamic"}

// passwordAuth cycling mirrors the tri-state config field (Phase 35):
// absent = inherit the on-by-default behaviour, true = explicitly on,
// false = opt this tunnel out of the password fallback entirely.
const (
	passwordAuthInherit = iota
	passwordAuthOn
	passwordAuthOff
	passwordAuthCount
)

var passwordAuthLabels = [...]string{"inherit (on)", "on", "off"}

const (
	fName = iota
	fType
	fSSH
	fLocal
	fRemote
	fIdentity
	fJump
	fSocks5User
	fSocks5Pass
	fPasswordAuth
	fTags
	fieldCount
)

// newTuberEditor builds the form. For modeEdit, t is the current tuber (its
// Enabled is preserved); existing lists the current names for uniqueness.
func newTuberEditor(mode editorMode, t config.Tuber, existing []string, ctrl controller.Controller) *tuberEditor {
	e := &tuberEditor{
		mode:     mode,
		original: t.Name,
		src:      t,
		enabled:  t.Enabled,
		existing: existing,
		ctrl:     ctrl,
		focus:    fName,
		errs:     map[string]string{},
		pal:      resolvePalette(detectKind()),
	}
	e.name = newInput(t.Name, "my-tuber", e.pal.body)
	e.ssh = newInput(t.SSH, "user@host:22", e.pal.body)
	e.local = newInput(t.Local, "5432 or 127.0.0.1:5432", e.pal.body)
	e.remote = newInput(t.Remote, "db:5432", e.pal.body)
	e.identity = newInput(t.Identity, "~/.ssh/id_ed25519 (optional)", e.pal.body)
	e.jump = newInput(t.Jump, "bastion:22 or user@b1:22,user@b2:22 (optional)", e.pal.body)
	e.socks5User = newInput(t.Socks5User, "user (dynamic only, overrides defaults)", e.pal.body)
	e.socks5Pass = newInput(t.Socks5Password, "password (dynamic only, overrides defaults)", e.pal.body)
	e.tags = newInput(strings.Join(t.Tags, ", "), "prod, db (optional, comma-separated)", e.pal.body)

	e.typeIdx = 0
	for i, ty := range tuberTypes {
		if ty == t.Type {
			e.typeIdx = i
			break
		}
	}
	e.passwordAuthIdx = passwordAuthInherit
	if t.PasswordAuth != nil {
		if *t.PasswordAuth {
			e.passwordAuthIdx = passwordAuthOn
		} else {
			e.passwordAuthIdx = passwordAuthOff
		}
	}
	e.applyTypePlaceholders()
	return e
}

// applyTypePlaceholders tunes the remote/local hints to the selected type so
// the form reflects each type's semantics (e.g. a -R remote may be a bare
// port that binds loopback on the host).
func (e *tuberEditor) applyTypePlaceholders() {
	dyn := tuberTypes[e.typeIdx] == "dynamic"
	switch tuberTypes[e.typeIdx] {
	case "remote":
		e.remote.Placeholder = "9090 or 0.0.0.0:9090"
		e.local.Placeholder = "127.0.0.1:9090"
	case "local":
		e.remote.Placeholder = "db:5432"
		e.local.Placeholder = "5432 or 127.0.0.1:5432"
	case "dynamic":
		e.local.Placeholder = "1080 or 127.0.0.1:1080"
		e.remote.Placeholder = "unused"
	}
	if dyn {
		e.socks5User.Placeholder = "user (overrides defaults)"
		e.socks5Pass.Placeholder = "password (overrides defaults)"
	} else {
		e.socks5User.Placeholder = "(dynamic only)"
		e.socks5Pass.Placeholder = "(dynamic only)"
	}
}

// typeNote is the one-line semantics hint shown under the Type field.
func (e *tuberEditor) typeNote() string {
	switch tuberTypes[e.typeIdx] {
	case "local":
		return "local: listened here · remote: destination dialed on the host"
	case "remote":
		return "remote: listened on the host — bare port binds all interfaces (*:port, needs GatewayPorts); loopback-only: 127.0.0.1:port"
	case "dynamic":
		return "local: SOCKS5 proxy here · remote unused (destination from the SOCKS request)"
	}
	return ""
}

func newInput(value, placeholder string, body lipgloss.Style) textinput.Model {
	ti := textinput.New()
	ti.Prompt = ""
	ti.Placeholder = placeholder
	ti.CharLimit = 256
	ti.SetWidth(40)
	ti.SetValue(value)
	s := ti.Styles()
	s.Focused.Text = body
	s.Blurred.Text = body
	ti.SetStyles(s)
	return ti
}

// update mutates the editor in place and returns any command (e.g. cursor
// blink from focusing a text field).
func (e *tuberEditor) update(msg tea.Msg) tea.Cmd {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		e.width, e.height = msg.Width, msg.Height
		return nil
	case tea.KeyPressMsg:
		return e.handleKey(msg)
	case tea.PasteMsg:
		// Forward bracketed-paste to the focused text field (textinput inserts
		// the content at the cursor). No-op when a non-text field (Type) is
		// focused.
		if ti := e.textInputFor(e.focus); ti != nil {
			var cmd tea.Cmd
			*ti, cmd = ti.Update(msg)
			return cmd
		}
		return nil
	}
	return nil
}

func (e *tuberEditor) handleKey(k tea.KeyPressMsg) tea.Cmd {
	switch k.String() {
	case "ctrl+s":
		e.trySave()
		return nil
	case "esc":
		e.done = true
		return nil
	case "tab", "enter":
		next := e.focus + 1
		if next >= fieldCount {
			next = 0
		}
		return e.setFocus(next)
	case "shift+tab":
		prev := e.focus - 1
		if prev < 0 {
			prev = fieldCount - 1
		}
		return e.setFocus(prev)
	case "left", "right":
		if e.focus == fType {
			if k.String() == "left" {
				e.cycleType(-1)
			} else {
				e.cycleType(1)
			}
			return nil
		}
		if e.focus == fPasswordAuth {
			if k.String() == "left" {
				e.cyclePasswordAuth(-1)
			} else {
				e.cyclePasswordAuth(1)
			}
			return nil
		}
	}
	if ti := e.textInputFor(e.focus); ti != nil {
		var cmd tea.Cmd
		*ti, cmd = ti.Update(k)
		return cmd
	}
	return nil
}

func (e *tuberEditor) textInputFor(idx int) *textinput.Model {
	switch idx {
	case fName:
		return &e.name
	case fSSH:
		return &e.ssh
	case fLocal:
		return &e.local
	case fRemote:
		return &e.remote
	case fIdentity:
		return &e.identity
	case fJump:
		return &e.jump
	case fSocks5User:
		return &e.socks5User
	case fSocks5Pass:
		return &e.socks5Pass
	case fTags:
		return &e.tags
	}
	return nil
}

func (e *tuberEditor) setFocus(idx int) tea.Cmd {
	if ti := e.textInputFor(e.focus); ti != nil {
		ti.Blur()
	}
	e.focus = idx
	if ti := e.textInputFor(idx); ti != nil {
		return ti.Focus()
	}
	return nil
}

func (e *tuberEditor) cycleType(dir int) {
	e.typeIdx = (e.typeIdx + dir + len(tuberTypes)) % len(tuberTypes)
	e.applyTypePlaceholders()
}

func (e *tuberEditor) cyclePasswordAuth(dir int) {
	e.passwordAuthIdx = (e.passwordAuthIdx + dir + passwordAuthCount) % passwordAuthCount
}

// tuber overlays the form inputs on src (the tuber the editor was opened on)
// so that config fields without a form input survive the save by construction.
func (e *tuberEditor) tuber() config.Tuber {
	t := e.src
	t.Name = e.name.Value()
	t.Type = tuberTypes[e.typeIdx]
	t.SSH = e.ssh.Value()
	t.Local = e.local.Value()
	t.Remote = e.remote.Value()
	t.Identity = e.identity.Value()
	t.Jump = e.jump.Value()
	t.Socks5User = e.socks5User.Value()
	t.Socks5Password = e.socks5Pass.Value()
	switch e.passwordAuthIdx {
	case passwordAuthOn:
		v := true
		t.PasswordAuth = &v
	case passwordAuthOff:
		v := false
		t.PasswordAuth = &v
	default:
		t.PasswordAuth = nil
	}
	t.Enabled = e.enabled
	t.Tags = parseEditorTags(e.tags.Value())
	return t
}

// parseEditorTags splits the comma-separated tags input into a clean []string:
// each token is trimmed, empties dropped, and duplicates removed (case-
// sensitive). Validation (validName, length/count caps) happens in config.Validate
// on save; the editor surfaces per-tag errors in validate().
func parseEditorTags(s string) []string {
	parts := strings.Split(s, ",")
	seen := make(map[string]struct{}, len(parts))
	var out []string
	for _, p := range parts {
		p = strings.TrimSpace(p)
		if p == "" {
			continue
		}
		if _, ok := seen[p]; ok {
			continue
		}
		seen[p] = struct{}{}
		out = append(out, p)
	}
	return out
}

// validate mirrors config.Validate per field so the form can highlight invalid
// inputs before calling the controller. The controller/daemon validate again
// (defence in depth).
func (e *tuberEditor) validate() map[string]string {
	errs := map[string]string{}
	t := e.tuber()

	name := strings.TrimSpace(t.Name)
	switch {
	case name == "":
		errs["name"] = "required"
	case !validEditorName(name):
		errs["name"] = "letters, digits, - or _ only"
	default:
		for _, n := range e.existing {
			if n == name && !(e.mode == modeEdit && n == e.original) {
				errs["name"] = "already exists"
				break
			}
		}
	}

	if strings.TrimSpace(t.Local) == "" {
		errs["local"] = "required"
	}
	if strings.TrimSpace(t.SSH) == "" {
		errs["ssh"] = "required"
	}
	if t.Type != "dynamic" && strings.TrimSpace(t.Remote) == "" {
		errs["remote"] = "required for " + t.Type
	}
	for _, tag := range parseEditorTags(e.tags.Value()) {
		if !validEditorName(tag) {
			errs["tags"] = "letters, digits, - or _ only (comma-separated)"
			break
		}
	}
	return errs
}

func (e *tuberEditor) trySave() {
	e.errs = e.validate()
	if len(e.errs) > 0 {
		e.status = "fix the highlighted fields"
		return
	}
	e.errs = map[string]string{}
	t := e.tuber()
	var err error
	if e.mode == modeNew {
		err = e.ctrl.AddTuber(t)
	} else {
		err = e.ctrl.UpdateTuber(e.original, t)
	}
	if err != nil {
		e.status = "error: " + err.Error()
		return
	}
	e.saved = true
	e.done = true
}

func (e *tuberEditor) view() string {
	var b strings.Builder
	title := "New tuber"
	if e.mode == modeEdit {
		title = "Edit tuber: " + e.original
	}
	b.WriteString(e.pal.editorTitle.Render(title))
	b.WriteString("\n\n")

	b.WriteString(e.renderText("Name", &e.name, fName, "name"))
	b.WriteString(e.renderType())
	b.WriteString("          " + e.pal.dim.Render(e.typeNote()) + "\n")
	b.WriteString(e.renderText("SSH", &e.ssh, fSSH, "ssh"))
	b.WriteString(e.renderText("Local", &e.local, fLocal, "local"))
	b.WriteString(e.renderText("Remote", &e.remote, fRemote, "remote"))
	b.WriteString(e.renderText("Identity", &e.identity, fIdentity, "identity"))
	b.WriteString(e.renderText("Jump", &e.jump, fJump, "jump"))
	b.WriteString(e.renderText("Socks5User", &e.socks5User, fSocks5User, "socks5_user"))
	b.WriteString(e.renderText("Socks5Pass", &e.socks5Pass, fSocks5Pass, "socks5_password"))
	b.WriteString(e.renderPasswordAuth())
	b.WriteString(e.renderText("Tags", &e.tags, fTags, "tags"))
	b.WriteString("\n")

	if e.status != "" {
		b.WriteString(e.pal.err.Render(e.status))
		b.WriteString("\n")
	}
	b.WriteString(e.pal.dim.Render("tab/enter next · shift+tab prev · ←/→ change type · ctrl+s save · esc cancel"))
	return e.pal.modal.Render(b.String())
}

func (e *tuberEditor) renderText(label string, ti *textinput.Model, idx int, key string) string {
	focused := e.focus == idx
	lab := fmt.Sprintf("%-9s", label+":")
	if focused {
		lab = e.pal.editorLabel.Render(lab)
	} else {
		lab = e.pal.dim.Render(lab)
	}
	line := lab + " " + ti.View()
	if msg, ok := e.errs[key]; ok {
		line += "  " + e.pal.err.Render("← "+msg)
	}
	return line + "\n"
}

func (e *tuberEditor) renderType() string {
	focused := e.focus == fType
	lab := fmt.Sprintf("%-9s", "Type:")
	if focused {
		lab = e.pal.editorLabel.Render(lab)
	} else {
		lab = e.pal.dim.Render(lab)
	}
	val := tuberTypes[e.typeIdx]
	if focused {
		val = e.pal.cursor.Render(val) + "  " + e.pal.dim.Render("←/→")
	} else {
		val = e.pal.dim.Render(val)
	}
	return lab + " " + val + "\n"
}

func (e *tuberEditor) renderPasswordAuth() string {
	focused := e.focus == fPasswordAuth
	lab := fmt.Sprintf("%-9s", "PassAuth:")
	if focused {
		lab = e.pal.editorLabel.Render(lab)
	} else {
		lab = e.pal.dim.Render(lab)
	}
	val := passwordAuthLabels[e.passwordAuthIdx]
	if focused {
		val = e.pal.cursor.Render(val) + "  " + e.pal.dim.Render("←/→")
	} else {
		val = e.pal.dim.Render(val)
	}
	return lab + " " + val + "\n"
}

func validEditorName(s string) bool {
	if s == "" {
		return false
	}
	for _, r := range s {
		switch {
		case r == '-' || r == '_':
		case r >= 'a' && r <= 'z':
		case r >= 'A' && r <= 'Z':
		case r >= '0' && r <= '9':
		default:
			return false
		}
	}
	return true
}
