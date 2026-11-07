//go:build windows

package main

import (
	"errors"
	"fmt"
	"github.com/ryan-flan/DOINK/companion/internal/config"
	"github.com/ryan-flan/DOINK/companion/internal/status"
	"github.com/ryan-flan/DOINK/companion/internal/updates"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync/atomic"
)

type bundleUpdater struct {
	configPath, appDir, version string
	st                          *status.Status
	quit                        func()
	busy                        atomic.Bool
}

func (u *bundleUpdater) Check() (*updates.Info, error) {
	cfg, err := config.Load(u.configPath, false)
	if err != nil && !errors.Is(err, config.ErrNoWoW) {
		return nil, err
	}
	info, err := updates.FetchBundle(nil, cfg.UpdateRepository, u.version)
	if err == nil {
		if !updates.IsNewer(u.version, info.Latest) {
			if dirs, e := updates.AddonDirs(cfg.SavedVariablesPaths); e == nil {
				for _, dir := range dirs {
					if updates.IsNewer(info.Latest, updates.AddonVersion(dir)) {
						info.NeedsAddon = true
					}
				}
			}
		}
		u.st.UpdateChecked(info)
	}
	return info, err
}
func (u *bundleUpdater) Install() {
	if !u.busy.CompareAndSwap(false, true) {
		return
	}
	defer u.busy.Store(false)
	defer u.st.Installing("")
	fail := func(err error) { u.st.Failed("Update: " + err.Error()) }
	closed := func() bool {
		running, err := updates.GameRunning()
		if err != nil {
			fail(fmt.Errorf("cannot check whether WoW is closed: %w", err))
			return false
		}
		if running {
			fail(errors.New("close World of Warcraft completely, then click Update both again"))
			return false
		}
		return true
	}
	if !closed() {
		return
	}
	cfg, err := config.Load(u.configPath, false)
	if err != nil {
		fail(err)
		return
	}
	if cfg.DryRun {
		fail(errors.New("updates are disabled in dry-run mode"))
		return
	}
	exe, err := os.Executable()
	if err != nil {
		fail(err)
		return
	}
	if !strings.EqualFold(filepath.Base(exe), updates.TripleExe) {
		fail(errors.New("keep the app filename DOINK - Triple K.exe before updating"))
		return
	}
	dirs, err := updates.AddonDirs(cfg.SavedVariablesPaths)
	if err != nil {
		fail(err)
		return
	}
	u.st.Installing("Checking the Triple K release…")
	info, err := u.Check()
	if err != nil {
		fail(err)
		return
	}
	if !info.Installable() {
		u.st.OK()
		return
	}
	u.st.Installing("Downloading addon + Companion v" + info.Latest + "…")
	data, err := updates.DownloadBundle(nil, info, cfg.UpdateRepository)
	if err != nil {
		fail(err)
		return
	}
	u.st.Installing("Verifying and preparing both components…")
	plan, err := updates.PrepareBundle(data, info, u.appDir, dirs)
	if err != nil {
		fail(err)
		return
	}
	defer plan.Close()
	if !closed() {
		return
	}
	u.st.Installing("Installing both components; keeping backups…")
	if err = plan.Apply(); err != nil {
		fail(err)
		return
	}
	cmd := exec.Command(exe, restartArgs(os.Args[1:], u.version)...)
	if err = cmd.Start(); err != nil {
		fail(errors.Join(fmt.Errorf("could not restart Companion: %w", err), plan.Rollback()))
		return
	}
	u.quit()
}
