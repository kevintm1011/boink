package discord

import (
	"github.com/ryan-flan/DOINK/companion/internal/brand"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestTripleKSenderLocksAllPosts(t *testing.T) {
	calls := 0
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { calls++; w.WriteHeader(204) }))
	defer server.Close()
	old := brand.ChannelWebhook
	brand.ChannelWebhook = server.URL
	defer func() { brand.ChannelWebhook = old }()
	p, _ := testPool(t, false, nil)
	if err := p.Send("http://invalid.invalid/other", []Embed{{"title": "test"}}); err != nil {
		t.Fatal(err)
	}
	if calls != 1 {
		t.Fatal("wrong destination")
	}
}
