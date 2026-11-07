package discord

import (
	"strings"
	"testing"
)

func TestAchievementEmbed(t *testing.T) {
	e := event("achievement", map[string]any{"id": "level_20", "title": "Level 20", "description": "Reach character level 20.", "category": "levels"})
	embed := BuildEmbed(e, nil)
	if embed["title"] != "Flano unlocked: Level 20" || embed["description"] != "Reach character level 20." {
		t.Fatal(embed)
	}
	if values := fieldValues(embed); len(values) != 1 || values[0] != "levels" {
		t.Fatal(values)
	}
	if embed["color"] != 0xE9BD53 {
		t.Fatal("missing achievement color")
	}
	e.Test = true
	if !strings.HasPrefix(BuildEmbed(e, nil)["title"].(string), "[TEST]") {
		t.Fatal("test not identified")
	}
}
