package discord

import (
	"bytes"
	"fmt"
	"image"
	"image/jpeg"
	_ "image/png"
	"os"
)

// SendScreenshot attaches only the file whose DOINK grid was validated by
// the runner. Re-encoding strips image metadata and bounds upload size.
func (p *Pool) SendScreenshot(url string, embeds []Embed, path string) error {
	f, err := os.Open(path)
	if err != nil {
		return err
	}
	defer f.Close()
	cfg, _, err := image.DecodeConfig(f)
	if err != nil {
		return err
	}
	if cfg.Width <= 0 || cfg.Height <= 0 || int64(cfg.Width)*int64(cfg.Height) > 40_000_000 {
		return fmt.Errorf("screenshot dimensions exceed 40 million pixels")
	}
	if _, err := f.Seek(0, 0); err != nil {
		return err
	}
	img, _, err := image.Decode(f)
	if err != nil {
		return err
	}
	var buf bytes.Buffer
	for _, quality := range []int{85, 65, 45} {
		buf.Reset()
		if err := jpeg.Encode(&buf, img, &jpeg.Options{Quality: quality}); err != nil {
			return err
		}
		if buf.Len() <= 8*1024*1024 {
			break
		}
	}
	if buf.Len() > 8*1024*1024 {
		return fmt.Errorf("screenshot exceeds 8 MiB upload budget")
	}
	copies := make([]Embed, len(embeds))
	for i, embed := range embeds {
		copies[i] = Embed{}
		for k, v := range embed {
			copies[i][k] = v
		}
	}
	if len(copies) > 0 {
		copies[0]["image"] = map[string]string{"url": "attachment://doink.jpg"}
	}
	return p.send(url, copies, buf.Bytes())
}
