package discord

import (
	"encoding/json"
	"image"
	"image/jpeg"
	"image/png"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"
)

func TestScreenshotMultipartRetry(t *testing.T) {
	path := filepath.Join(t.TempDir(), "shot.png")
	f, err := os.Create(path)
	if err != nil {
		t.Fatal(err)
	}
	if err := png.Encode(f, image.NewRGBA(image.Rect(0, 0, 64, 32))); err != nil {
		t.Fatal(err)
	}
	f.Close()
	calls := 0
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls++
		if err := r.ParseMultipartForm(10 << 20); err != nil {
			t.Error(err)
			w.WriteHeader(400)
			return
		}
		defer r.MultipartForm.RemoveAll()
		var payload struct {
			Embeds []struct{ Image struct{ URL string } }
		}
		if err := json.Unmarshal([]byte(r.FormValue("payload_json")), &payload); err != nil {
			t.Error(err)
		}
		if len(payload.Embeds) != 1 || payload.Embeds[0].Image.URL != "attachment://doink.jpg" {
			t.Errorf("bad payload: %s", r.FormValue("payload_json"))
		}
		photo, header, err := r.FormFile("files[0]")
		if err != nil {
			t.Error(err)
			w.WriteHeader(400)
			return
		}
		defer photo.Close()
		if header.Filename != "doink.jpg" {
			t.Error(header.Filename)
		}
		img, err := jpeg.Decode(photo)
		if err != nil {
			t.Error(err)
		} else if img.Bounds().Dx() != 64 {
			t.Error(img.Bounds())
		}
		if calls == 1 {
			w.WriteHeader(429)
			w.Write([]byte(`{"retry_after":0}`))
			return
		}
		w.WriteHeader(204)
	}))
	defer srv.Close()
	p, _ := testPool(t, false, nil)
	original := []Embed{{"title": "level up"}}
	if err := p.SendScreenshot(srv.URL, original, path); err != nil {
		t.Fatal(err)
	}
	if calls != 2 {
		t.Fatalf("got %d attempts", calls)
	}
	if original[0]["image"] != nil {
		t.Fatal("mutated input")
	}
}

func TestScreenshotMissingFileDoesNotPost(t *testing.T) {
	p, _ := testPool(t, false, nil)
	if err := p.SendScreenshot("unused", embeds, filepath.Join(t.TempDir(), "missing.png")); err == nil {
		t.Fatal("expected read error")
	}
}
