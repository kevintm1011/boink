package settings

import (
	"github.com/ryan-flan/DOINK/companion/internal/brand"
	"os"
	"strings"
	"testing"
)

func TestTripleKSettingsHideAndIgnoreWebhook(t *testing.T) {
	old := brand.ChannelWebhook
	brand.ChannelWebhook = "https://discord.com/api/webhooks/1/triple-test"
	defer func() { brand.ChannelWebhook = old }()
	b := backend(t, "webhook_url = 'https://discord.com/api/webhooks/2/old'\n")
	v := b.View()
	if !v.ChannelLocked || v.Webhook != "" || v.GameWebhook != "" {
		t.Fatal("channel credential exposed")
	}
	if result := b.Save("https://discord.com/api/webhooks/3/override", ""); result.Error != "" {
		t.Fatal(result.Error)
	}
	bytes, _ := os.ReadFile(b.ConfigPath)
	if strings.Contains(string(bytes), "triple-test") || strings.Contains(string(bytes), "override") {
		t.Fatal("credential persisted")
	}
	var sent string
	b.Send = func(url string) error { sent = url; return nil }
	if msg := b.Test("https://discord.com/api/webhooks/3/override"); msg != "" {
		t.Fatal(msg)
	}
	if sent != brand.ChannelWebhook {
		t.Fatal("test bypassed channel lock")
	}
}

func TestUpdateRepositorySettings(t *testing.T) {
	b := backend(t, "")
	if msg := b.SetUpdateRepository("https://github.com/a/b"); msg == "" {
		t.Fatal("invalid repository accepted")
	}
	if msg := b.SetUpdateRepository("team/triple-k"); msg != "" {
		t.Fatal(msg)
	}
	if b.View().UpdateRepository != "team/triple-k" {
		t.Fatal("source not persisted")
	}
}
