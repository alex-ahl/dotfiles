---
name: page-screenshot
description: Use when you need to see a web page or HTML file you built — "screenshot the page", "check how the design looks", "does the layout render right", a localhost dev/preview URL, or a local .html file. Renders it with headless Chromium and gives you a PNG to read. Use this instead of launching Chrome, Chromium or Playwright yourself.
---

# Page Screenshot

Render a page to a PNG, then read the PNG to see it.

## Steps

1. Run the script with a URL or a file path, and where to write the PNG:

   ```
   ~/.scripts/shared/page-shot.sh <url-or-file> <out.png> [width] [height]
   ```

   - Viewport defaults to 1280×800; the shot is full-page. Pass `390 844` for a phone.
   - For a dev or preview server, start it first and pass its URL, e.g. `http://localhost:4321`.
   - Write the PNG to a scratch folder, not into the repo.

2. Act on the exit code:
   - **0** — stdout is the PNG path. Read it.
   - **2** — usage error; fix the arguments.
   - **other** — install or render failure; stderr has the cause. An egress block on first run
     means a download host is missing from the allowlist: name the host to the user.

3. The first run installs Playwright and Chromium under `~/.cache/page-shot` and takes a minute.
   Later runs take about a second.

## Notes

- Don't launch Google Chrome, Brave, Firefox or WebKit directly, or Playwright's Chromium
  without `--single-process`: they abort under the sandbox. The script handles this.
- One page per run. To compare widths or pages, run it once per shot.
