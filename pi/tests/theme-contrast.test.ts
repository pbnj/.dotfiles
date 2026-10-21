import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

// Pi renders these tokens as foreground text, not diff background colors.
// Require WCAG AA text contrast on every possible tool-panel background.
const foregrounds = [
  "toolDiffAdded",
  "toolDiffRemoved",
  "toolDiffContext",
  "toolOutput",
];
const backgrounds = ["toolPendingBg", "toolSuccessBg", "toolErrorBg"];

function luminance(hex: string): number {
  assert.match(hex, /^#[0-9a-f]{6}$/i);
  const channels = [1, 3, 5].map((offset) => {
    const value = Number.parseInt(hex.slice(offset, offset + 2), 16) / 255;
    return value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4;
  });
  return channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722;
}

function contrast(foreground: string, background: string): number {
  const a = luminance(foreground);
  const b = luminance(background);
  return (Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05);
}

for (const variant of ["Day", "Moon"]) {
  const theme = JSON.parse(
    readFileSync(
      new URL(
        `../.pi/agent/themes/Tokyo Night ${variant}.json`,
        import.meta.url,
      ),
      "utf8",
    ),
  ) as { colors: Record<string, string> };

  for (const foreground of foregrounds) {
    test(`Tokyo Night ${variant}: ${foreground} has readable tool-panel contrast`, () => {
      for (const background of backgrounds) {
        const ratio = contrast(
          theme.colors[foreground],
          theme.colors[background],
        );
        assert.ok(
          ratio >= 4.5,
          `${foreground} on ${background}: ${ratio.toFixed(2)}:1, expected >= 4.5:1`,
        );
      }
    });
  }
}
