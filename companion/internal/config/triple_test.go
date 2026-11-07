package config

import (
	"github.com/ryan-flan/DOINK/companion/internal/brand"
	"path/filepath"
	"testing"
)

func TestTripleKBuiltInConfig(t *testing.T) {
	old := brand.ChannelWebhook
	brand.ChannelWebhook = "https://discord.com/api/webhooks/1/triple-test"
	defer func() { brand.ChannelWebhook = old }()
	cfg, err := Load(setup(t, "savedvariables_path = '"+filepath.Join(t.TempDir(), "DOINK.lua")+"'\nwebhook_url = 'stale invalid value'\nupdate_check = true\nupdate_notify = true\n"), false)
	if err != nil {
		t.Fatal(err)
	}
	if cfg.WebhookURL != brand.ChannelWebhook || !cfg.UpdateCheck || !cfg.UpdateNotify {
		t.Fatal("wrong Triple K configuration")
	}
}
