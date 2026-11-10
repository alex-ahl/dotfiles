#!/usr/bin/env bash
# page-shot — screenshot a web page or local HTML file with headless Chromium.
#
# Usage: page-shot <url-or-file> <out.png> [width] [height]
#   width/height set the viewport (default 1280x800); the shot is full-page.
# Exit: 0 ok (prints the PNG path), 2 usage, other = install or render failure.
#
# First run installs Playwright and its chromium-headless-shell under $DIR and
# reuses them after. The download needs registry.npmjs.org, cdn.playwright.dev,
# playwright.download.prss.microsoft.com and storage.googleapis.com (the CDN
# redirects the Chromium zip there) on the srt allowlist.
#
# Workaround, remove when srt can allow Mach service registration:
#   - --single-process: under srt, Chromium's browser process can't register its
#     MachPortRendezvousServer, so multi-process launch aborts. srt has no
#     setting for that yet (allowMachLookup covers lookups only). Once it gains
#     one (`allowMachRegister`), allow register + lookup for
#     `org.chromium.Chromium.MachPortRendezvousServer.*` in
#     scripts/lib/srt-settings.json and drop the flag.
#     Watch: https://github.com/anthropics/sandbox-runtime/pull/598
#     (issue https://github.com/anthropics/sandbox-runtime/issues/210)
#   - chromium-headless-shell, not Google Chrome: Chrome also aborts reading
#     sysctl `hw.model`, which srt's fixed sysctl list omits and no setting adds.
#     The headless shell skips that read. #425 adds `hw.model`, but Chrome also
#     needs at least one more denied sysctl (`hw.product` or `kern.uuid`).
#     Watch: https://github.com/anthropics/sandbox-runtime/pull/425
#   - If both are fixed, this script may be unnecessary: plain Chrome headless
#     with --screenshot would do.
set -Eeuo pipefail

DIR="${PAGE_SHOT_HOME:-$HOME/.cache/page-shot}"
export PLAYWRIGHT_BROWSERS_PATH="$DIR/browsers"

usage() {
  echo "usage: page-shot <url-or-file> <out.png> [width] [height]" >&2
  exit 2
}

install_playwright() {
  [ -d "$DIR/node_modules/playwright" ] && return
  mkdir -p "$DIR"
  npm install --prefix "$DIR" --no-audit --no-fund --silent playwright >&2
}

install_browser() {
  compgen -G "$PLAYWRIGHT_BROWSERS_PATH/chromium_headless_shell-*" >/dev/null && return
  "$DIR/node_modules/.bin/playwright" install chromium-headless-shell >&2
}

# A path that exists on disk becomes a file:// URL; anything else is a URL.
to_url() {
  if [ -e "$1" ]; then
    printf 'file://%s' "$(cd "$(dirname "$1")" && pwd -P)/$(basename "$1")"
    return
  fi
  printf '%s' "$1"
}

shoot() {  # $1 = url, $2 = out, $3 = width, $4 = height
  node --input-type=module -e '
    const [url, out, width, height] = process.argv.slice(1);
    const { chromium } = await import(process.env.PAGE_SHOT_PLAYWRIGHT);
    const browser = await chromium.launch({ args: ["--single-process"] });
    const page = await browser.newPage({ viewport: { width: +width, height: +height } });
    await page.goto(url, { waitUntil: "load" });
    await page.screenshot({ path: out, fullPage: true });
    await browser.close();
  ' "$@"
}

[ $# -ge 2 ] && [ $# -le 4 ] || usage

install_playwright
install_browser

out="$(cd "$(dirname "$2")" && pwd -P)/$(basename "$2")"
PAGE_SHOT_PLAYWRIGHT="$DIR/node_modules/playwright/index.mjs" \
  shoot "$(to_url "$1")" "$out" "${3:-1280}" "${4:-800}"
echo "$out"
