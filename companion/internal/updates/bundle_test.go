package updates

import (
	"archive/zip"
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func bundleBytes(t *testing.T, extra map[string]string) []byte {
	t.Helper()
	entries := map[string]string{"DOINK/DOINK.toc": "## Title: DOINK - Triple K\n## Version: 0.18.0\n", "DOINK/Core.lua": "new addon", "Companion/" + TripleExe: "MZnew companion"}
	for k, v := range extra {
		entries[k] = v
	}
	var buf bytes.Buffer
	z := zip.NewWriter(&buf)
	for k, v := range entries {
		w, err := z.Create(k)
		if err != nil {
			t.Fatal(err)
		}
		w.Write([]byte(v))
	}
	z.Close()
	return buf.Bytes()
}
func bundleInfo(data []byte) *Info {
	sum := sha256.Sum256(data)
	return &Info{Current: "0.17.0", Latest: "0.18.0", BundleSHA256: hex.EncodeToString(sum[:]), ZipURL: "https://github.com/team/triple/releases/download/v0.18.0/update.zip"}
}
func installation(t *testing.T) (string, string, string) {
	t.Helper()
	root := t.TempDir()
	app := filepath.Join(root, "app")
	addon := filepath.Join(root, "game", "Interface", "AddOns", "DOINK")
	for _, p := range []string{app, addon} {
		if e := os.MkdirAll(p, 0755); e != nil {
			t.Fatal(e)
		}
	}
	os.WriteFile(filepath.Join(app, TripleExe), []byte("MZold companion"), 0644)
	os.WriteFile(filepath.Join(app, "config.toml"), []byte("personal settings"), 0644)
	os.WriteFile(filepath.Join(app, "state.json"), []byte("personal state"), 0644)
	os.WriteFile(filepath.Join(addon, "DOINK.toc"), []byte("## Version: 0.17.0\n"), 0644)
	os.WriteFile(filepath.Join(addon, "Core.lua"), []byte("old addon"), 0644)
	saved := filepath.Join(root, "game", "WTF", "Account", "A", "SavedVariables", "DOINK.lua")
	os.MkdirAll(filepath.Dir(saved), 0755)
	os.WriteFile(saved, []byte("character progress"), 0644)
	return app, addon, saved
}
func assertFile(t *testing.T, p, want string) {
	t.Helper()
	b, e := os.ReadFile(p)
	if e != nil || string(b) != want {
		t.Fatalf("%s: %q %v", p, b, e)
	}
}
func TestBundleInstallAndRollback(t *testing.T) {
	app, addon, sv := installation(t)
	data := bundleBytes(t, nil)
	plan, err := PrepareBundle(data, bundleInfo(data), app, []string{addon})
	if err != nil {
		t.Fatal(err)
	}
	defer plan.Close()
	assertFile(t, filepath.Join(addon, "Core.lua"), "old addon")
	if err = plan.Apply(); err != nil {
		t.Fatal(err)
	}
	assertFile(t, filepath.Join(addon, "Core.lua"), "new addon")
	assertFile(t, filepath.Join(app, TripleExe), "MZnew companion")
	assertFile(t, filepath.Join(app, "config.toml"), "personal settings")
	assertFile(t, filepath.Join(app, "state.json"), "personal state")
	assertFile(t, sv, "character progress")
	for _, p := range plan.Backups() {
		if _, err := os.Stat(p); err != nil {
			t.Fatal(err)
		}
	}
	if err = plan.Rollback(); err != nil {
		t.Fatal(err)
	}
	assertFile(t, filepath.Join(addon, "Core.lua"), "old addon")
	assertFile(t, filepath.Join(app, TripleExe), "MZold companion")
}
func TestBundleMidInstallFailureRestoresBoth(t *testing.T) {
	app, addon, _ := installation(t)
	data := bundleBytes(t, nil)
	plan, e := PrepareBundle(data, bundleInfo(data), app, []string{addon})
	if e != nil {
		t.Fatal(e)
	}
	defer plan.Close()
	calls := 0
	plan.Rename = func(a, b string) error {
		calls++
		if calls == 4 {
			return errors.New("simulated permission failure")
		}
		return os.Rename(a, b)
	}
	if plan.Apply() == nil {
		t.Fatal("expected failure")
	}
	assertFile(t, filepath.Join(addon, "Core.lua"), "old addon")
	assertFile(t, filepath.Join(app, TripleExe), "MZold companion")
}
func TestBundleRejectsUnsafeOrMismatchedPackages(t *testing.T) {
	for _, entry := range []string{"../escape", "DOINK/../escape", "DOINK/C:/escape", "DOINK/evil. ", "DOINK/core.lua", "/root", ".."} {
		t.Run(entry, func(t *testing.T) {
			app, addon, _ := installation(t)
			data := bundleBytes(t, map[string]string{entry: "bad"})
			if p, e := PrepareBundle(data, bundleInfo(data), app, []string{addon}); e == nil {
				p.Close()
				t.Fatal("unsafe package accepted")
			}
			assertFile(t, filepath.Join(addon, "Core.lua"), "old addon")
		})
	}
	app, addon, _ := installation(t)
	data := bundleBytes(t, nil)
	info := bundleInfo(data)
	info.BundleSHA256 = strings.Repeat("0", 64)
	if _, e := PrepareBundle(data, info, app, []string{addon}); e == nil {
		t.Fatal("checksum accepted")
	}
	info = bundleInfo(data)
	info.Latest = "0.19.0"
	if _, e := PrepareBundle(data, info, app, []string{addon}); e == nil {
		t.Fatal("wrong addon version accepted")
	}
	info = bundleInfo(data)
	info.Current = "0.19.0"
	if _, e := PrepareBundle(data, info, app, []string{addon}); e == nil {
		t.Fatal("downgrade accepted")
	}
}
func TestBundleMultipleAddonsAndDiscovery(t *testing.T) {
	app, addon, sv := installation(t)
	_, second, sv2 := installation(t)
	dirs, e := AddonDirs([]string{sv, sv, sv2, "/unrelated/DOINK.lua"})
	if e != nil || len(dirs) != 2 {
		t.Fatal(dirs, e)
	}
	data := bundleBytes(t, nil)
	plan, e := PrepareBundle(data, bundleInfo(data), app, []string{addon, second})
	if e != nil {
		t.Fatal(e)
	}
	defer plan.Close()
	if e = plan.Apply(); e != nil {
		t.Fatal(e)
	}
	assertFile(t, filepath.Join(second, "Core.lua"), "new addon")
}
func TestBundleRejectsSymlinkInstallation(t *testing.T) {
	app, addon, _ := installation(t)
	link := filepath.Join(t.TempDir(), "DOINK")
	if e := os.Symlink(addon, link); e != nil {
		t.Skip(e)
	}
	data := bundleBytes(t, nil)
	if p, e := PrepareBundle(data, bundleInfo(data), app, []string{link}); e == nil {
		p.Close()
		t.Fatal("symlink accepted")
	}
}

type bundleTransport func(*http.Request) (*http.Response, error)

func (f bundleTransport) RoundTrip(r *http.Request) (*http.Response, error) { return f(r) }
func TestBundleManifestAndDownload(t *testing.T) {
	data := bundleBytes(t, nil)
	info := bundleInfo(data)
	m := Manifest{1, "DOINK-Triple-K", "0.18.0", info.ZipURL, info.BundleSHA256}
	raw, _ := json.Marshal(m)
	client := &http.Client{Transport: bundleTransport(func(r *http.Request) (*http.Response, error) {
		b := raw
		if strings.HasSuffix(r.URL.Path, ".zip") {
			b = data
		}
		return &http.Response{StatusCode: 200, Body: io.NopCloser(bytes.NewReader(b)), Header: make(http.Header)}, nil
	})}
	got, e := FetchBundle(client, "team/triple", "0.17.0")
	if e != nil || !got.Installable() {
		t.Fatal(got, e)
	}
	downloaded, e := DownloadBundle(client, got, "team/triple")
	if e != nil || !bytes.Equal(downloaded, data) {
		t.Fatal(e)
	}
	if e = ValidateManifest(m, "other/repo"); e == nil {
		t.Fatal("cross-repo URL accepted")
	}
	m.URL = "http://github.com/team/triple/releases/download/v0.18.0/update.zip"
	if ValidateManifest(m, "team/triple") == nil {
		t.Fatal("HTTP accepted")
	}
	for _, repo := range []string{"../other", "x/y/z", "https://github.com/x/y", "x/..", "x/y?x"} {
		if ValidRepository(repo) {
			t.Fatal(repo)
		}
	}
}
func TestBundleRepairsOlderAddonWithoutDowngrading(t *testing.T) {
	app, addon, _ := installation(t)
	data := bundleBytes(t, nil)
	info := bundleInfo(data)
	info.Current = info.Latest
	info.NeedsAddon = true
	plan, e := PrepareBundle(data, info, app, []string{addon})
	if e != nil {
		t.Fatal(e)
	}
	plan.Close()
	os.WriteFile(filepath.Join(addon, "DOINK.toc"), []byte("## Version: 0.19.0\n"), 0644)
	if _, e = PrepareBundle(data, info, app, []string{addon}); e == nil {
		t.Fatal("newer addon downgraded")
	}
}
