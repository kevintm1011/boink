package updates

import (
	"archive/zip"
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"path"
	"path/filepath"
	"regexp"
	"strings"
	"time"
)

const TripleExe = "DOINK - Triple K.exe"

var repositoryRE = regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9_.-]*/[A-Za-z0-9][A-Za-z0-9_.-]*$`)
var releaseVersionRE = regexp.MustCompile(`^[0-9]+\.[0-9]+\.[0-9]+$`)

func ValidRepository(repo string) bool {
	return repositoryRE.MatchString(repo) && !strings.Contains(repo, "..")
}

type Manifest struct {
	Schema  int    `json:"schema"`
	Product string `json:"product"`
	Version string `json:"version"`
	URL     string `json:"url"`
	SHA256  string `json:"sha256"`
}

func manifestClient() *http.Client {
	return &http.Client{Timeout: 2 * time.Minute, CheckRedirect: func(req *http.Request, via []*http.Request) error {
		if len(via) > 8 {
			return errors.New("too many redirects")
		}
		host := req.URL.Hostname()
		if req.URL.Scheme != "https" || (host != "github.com" && host != "release-assets.githubusercontent.com" && host != "objects.githubusercontent.com" && host != "github-releases.githubusercontent.com") {
			return errors.New("unexpected download redirect")
		}
		return nil
	}}
}
func fetchBounded(client *http.Client, raw string, limit int64) ([]byte, error) {
	if client == nil {
		client = manifestClient()
	}
	resp, err := client.Get(raw)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("download returned HTTP %d", resp.StatusCode)
	}
	data, err := io.ReadAll(io.LimitReader(resp.Body, limit+1))
	if err != nil {
		return nil, err
	}
	if int64(len(data)) > limit {
		return nil, errors.New("download exceeds size limit")
	}
	return data, nil
}
func ValidateManifest(m Manifest, repo string) error {
	if !ValidRepository(repo) || m.Schema != 1 || m.Product != "DOINK-Triple-K" || !releaseVersionRE.MatchString(m.Version) || !sha256RE.MatchString(m.SHA256) {
		return errors.New("invalid Triple K release manifest")
	}
	u, err := url.Parse(m.URL)
	prefix := "/" + repo + "/releases/download/"
	if err != nil || u.Scheme != "https" || u.Host != "github.com" || u.User != nil || u.RawQuery != "" || u.Fragment != "" || !strings.HasPrefix(u.Path, prefix) || path.Clean(u.Path) != u.Path || !strings.HasSuffix(u.Path, ".zip") {
		return errors.New("release download must belong to the configured GitHub repository")
	}
	return nil
}
func FetchBundle(client *http.Client, repo, current string) (*Info, error) {
	if !ValidRepository(repo) {
		return nil, errors.New("set your Triple K update repository in Settings first (owner/repository)")
	}
	data, err := fetchBounded(client, "https://github.com/"+repo+"/releases/latest/download/update.json", 64<<10)
	if err != nil {
		return nil, err
	}
	var m Manifest
	if err = json.Unmarshal(data, &m); err != nil {
		return nil, errors.New("invalid update.json")
	}
	if err = ValidateManifest(m, repo); err != nil {
		return nil, err
	}
	return &Info{Current: current, Latest: m.Version, URL: "https://github.com/" + repo + "/releases/latest", ZipURL: m.URL, BundleSHA256: m.SHA256, CheckedAt: time.Now()}, nil
}

// AddonDirs only derives existing installations from discovered SavedVariables.
func AddonDirs(savedVariables []string) ([]string, error) {
	var dirs []string
	seen := map[string]bool{}
	for _, sv := range savedVariables {
		saved := filepath.Dir(sv)
		account := filepath.Dir(filepath.Dir(saved))
		wtf := filepath.Dir(account)
		if !strings.EqualFold(filepath.Base(saved), "SavedVariables") || !strings.EqualFold(filepath.Base(account), "Account") || !strings.EqualFold(filepath.Base(wtf), "WTF") {
			continue
		}
		dir := filepath.Join(filepath.Dir(wtf), "Interface", "AddOns", "DOINK")
		if _, err := os.Stat(filepath.Join(dir, "DOINK.toc")); err != nil {
			continue
		}
		key := strings.ToLower(filepath.Clean(dir))
		if !seen[key] {
			seen[key] = true
			dirs = append(dirs, dir)
		}
	}
	if len(dirs) == 0 {
		return nil, errors.New("no installed DOINK addon found; select your WoW folder in Settings and log into the addon once")
	}
	return dirs, nil
}

func unpackBundle(data []byte, version string) (map[string][]byte, []byte, error) {
	z, err := zip.NewReader(bytes.NewReader(data), int64(len(data)))
	if err != nil {
		return nil, nil, err
	}
	if len(z.File) > 1024 {
		return nil, nil, errors.New("too many archive entries")
	}
	files := map[string][]byte{}
	seen := map[string]bool{}
	var exe []byte
	var total uint64
	for _, f := range z.File {
		name := strings.ReplaceAll(f.Name, "\\", "/")
		clean := strings.TrimSuffix(name, "/")
		if clean == "" || clean == "." || clean == ".." || strings.HasPrefix(clean, "/") || strings.Contains(clean, ":") || path.Clean(clean) != clean || strings.HasPrefix(clean, "../") || f.Mode()&os.ModeSymlink != 0 {
			return nil, nil, errors.New("unsafe archive entry")
		}
		// Windows normalizes trailing dots/spaces and ignores case.
		for _, part := range strings.Split(clean, "/") {
			if strings.TrimRight(part, " .") != part {
				return nil, nil, errors.New("ambiguous archive path")
			}
		}
		key := strings.ToLower(clean)
		if seen[key] {
			return nil, nil, errors.New("duplicate archive entry")
		}
		seen[key] = true
		if f.FileInfo().IsDir() {
			continue
		}
		if !strings.HasPrefix(name, "DOINK/") && name != "Companion/"+TripleExe {
			continue
		}
		total += f.UncompressedSize64
		if total > 128<<20 || f.UncompressedSize64 > 32<<20 {
			return nil, nil, errors.New("unpacked update is too large")
		}
		rc, err := f.Open()
		if err != nil {
			return nil, nil, err
		}
		b, readErr := io.ReadAll(io.LimitReader(rc, (32<<20)+1))
		rc.Close()
		if readErr != nil {
			return nil, nil, readErr
		}
		if len(b) > 32<<20 {
			return nil, nil, errors.New("file exceeds size limit")
		}
		if name == "Companion/"+TripleExe {
			exe = b
		} else {
			files[strings.TrimPrefix(name, "DOINK/")] = b
		}
	}
	toc := string(files["DOINK.toc"])
	if !regexp.MustCompile(`(?m)^## Title: DOINK - Triple K\r?$`).MatchString(toc) || !regexp.MustCompile(`(?m)^## Version: `+regexp.QuoteMeta(version)+`\r?$`).MatchString(toc) || len(files["Core.lua"]) == 0 {
		return nil, nil, errors.New("addon version/branding does not match release")
	}
	if len(exe) < 2 || !bytes.HasPrefix(exe, []byte("MZ")) {
		return nil, nil, errors.New("release does not contain the Windows Companion")
	}
	return files, exe, nil
}
func AddonVersion(dir string) string {
	b, err := os.ReadFile(filepath.Join(dir, "DOINK.toc"))
	if err != nil {
		return ""
	}
	m := regexp.MustCompile(`(?m)^## Version: ([^\r\n]+)`).FindSubmatch(b)
	if len(m) != 2 {
		return ""
	}
	return strings.TrimSpace(string(m[1]))
}
func plainPath(target string) error {
	abs, err := filepath.Abs(target)
	if err != nil {
		return err
	}
	for p := abs; ; p = filepath.Dir(p) {
		fi, err := os.Lstat(p)
		if err != nil {
			return err
		}
		if fi.Mode()&os.ModeSymlink != 0 {
			return fmt.Errorf("update path is a link: %s", p)
		}
		if filepath.Dir(p) == p {
			break
		}
	}
	return nil
}

type change struct{ target, staged, backup string }
type BundlePlan struct {
	changes   []change
	committed int
	Rename    func(string, string) error
}

func (p *BundlePlan) rename(a, b string) error {
	if p.Rename != nil {
		return p.Rename(a, b)
	}
	return os.Rename(a, b)
}
func (p *BundlePlan) Close() {
	for _, c := range p.changes {
		os.RemoveAll(c.staged)
	}
}
func (p *BundlePlan) Backups() []string {
	var paths []string
	for _, c := range p.changes {
		paths = append(paths, c.backup)
	}
	return paths
}

// Prepare stages on each target filesystem. No installed files change yet.
func PrepareBundle(data []byte, info *Info, appDir string, addonDirs []string) (*BundlePlan, error) {
	if info == nil || !info.Newer() || IsNewer(info.Current, info.Latest) || !sha256RE.MatchString(info.BundleSHA256) {
		return nil, errors.New("no newer verified release selected")
	}
	sum := sha256.Sum256(data)
	if hex.EncodeToString(sum[:]) != info.BundleSHA256 {
		return nil, errors.New("update checksum mismatch; nothing installed")
	}
	files, exe, err := unpackBundle(data, info.Latest)
	if err != nil {
		return nil, err
	}
	if len(addonDirs) == 0 {
		return nil, errors.New("no addon installation selected")
	}
	p := &BundlePlan{}
	success := false
	defer func() {
		if !success {
			p.Close()
		}
	}()
	stamp := fmt.Sprintf("%d", time.Now().UnixNano())
	seen := map[string]bool{}
	for _, dir := range addonDirs {
		abs, err := filepath.Abs(dir)
		if err != nil {
			return nil, err
		}
		key := strings.ToLower(abs)
		if seen[key] {
			continue
		}
		seen[key] = true
		if IsNewer(AddonVersion(dir), info.Latest) {
			return nil, errors.New("installed addon is newer than this release; refusing downgrade")
		}
		if filepath.Base(dir) != "DOINK" {
			return nil, errors.New("unexpected addon folder")
		}
		if err = plainPath(dir); err != nil {
			return nil, err
		}
		if err = plainPath(filepath.Join(dir, "DOINK.toc")); err != nil {
			return nil, err
		}
		staged, err := os.MkdirTemp(filepath.Dir(dir), ".doink-stage-")
		if err != nil {
			return nil, err
		}
		p.changes = append(p.changes, change{dir, staged, dir + ".triplek-backup-" + stamp})
		for name, b := range files {
			dst := filepath.Join(staged, filepath.FromSlash(name))
			if err = os.MkdirAll(filepath.Dir(dst), 0755); err != nil {
				return nil, err
			}
			if err = os.WriteFile(dst, b, 0644); err != nil {
				return nil, err
			}
		}
	}
	target := filepath.Join(appDir, TripleExe)
	if err = plainPath(target); err != nil {
		return nil, err
	}
	f, err := os.CreateTemp(appDir, ".triplek-exe-*.new")
	if err != nil {
		return nil, err
	}
	p.changes = append(p.changes, change{target, f.Name(), target + ".triplek-backup-" + stamp})
	_, err = f.Write(exe)
	closeErr := f.Close()
	if err != nil {
		return nil, err
	}
	if closeErr != nil {
		return nil, closeErr
	}
	success = true
	return p, nil
}
func (p *BundlePlan) Apply() error {
	if p.committed != 0 {
		return errors.New("update transaction already started")
	}
	for _, c := range p.changes {
		if err := p.rename(c.target, c.backup); err != nil {
			return errors.Join(err, p.Rollback())
		}
		if err := p.rename(c.staged, c.target); err != nil {
			restore := p.rename(c.backup, c.target)
			return errors.Join(err, restore, p.Rollback())
		}
		p.committed++
	}
	return nil
}
func (p *BundlePlan) Rollback() error {
	var errs []error
	for p.committed > 0 {
		p.committed--
		c := p.changes[p.committed]
		if err := os.RemoveAll(c.target); err != nil {
			errs = append(errs, err)
			continue
		}
		if err := p.rename(c.backup, c.target); err != nil {
			errs = append(errs, err)
		}
	}
	return errors.Join(errs...)
}
func DownloadBundle(client *http.Client, info *Info, repo string) ([]byte, error) {
	if info == nil {
		return nil, errors.New("no release selected")
	}
	m := Manifest{1, "DOINK-Triple-K", info.Latest, info.ZipURL, info.BundleSHA256}
	if err := ValidateManifest(m, repo); err != nil {
		return nil, err
	}
	return fetchBounded(client, info.ZipURL, 64<<20)
}
