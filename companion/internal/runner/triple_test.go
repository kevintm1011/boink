package runner

import (
	"github.com/ryan-flan/DOINK/companion/internal/brand"
	"github.com/ryan-flan/DOINK/companion/internal/config"
	"testing"
)

func TestTripleKIgnoresOtherDestinations(t *testing.T) {
	old := brand.ChannelWebhook
	brand.ChannelWebhook = "https://discord.com/api/webhooks/1/triple-test"
	defer func() { brand.ChannelWebhook = old }()
	got := WebhookFor("A-R", map[string]string{"A-R": "character", "*": "account"}, &config.Config{WebhookURL: "config"})
	if got != brand.ChannelWebhook {
		t.Fatal("channel override did not win")
	}
}
