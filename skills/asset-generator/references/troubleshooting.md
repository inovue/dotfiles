# Asset Generator Troubleshooting & Operations

### 1. Missing genmedia / fal auth
- **Symptom**: `genmedia CLI is not available`, `genmedia auth is not configured`, or genmedia auth errors at generation time.
- **Note**: Auth is checked **before** paid API calls (generate/rembg). `--print-prompt` dry-run still works without a key.
- **Fix**:
  ```bash
  curl https://genmedia.sh/install -fsS | bash
  export FAL_KEY="your_key"
  # or persist: genmedia setup --non-interactive --api-key "$FAL_KEY"
  # Bitwarden wrap (optional): export GENMEDIA_BIN="bws run -- genmedia"
  # (skill hydrates FAL_KEY via `bws run -- printenv FAL_KEY`, then calls real genmedia —
  #  avoids multiline --prompt breakage through shell wrappers)
  genmedia version --json
  ```

### 2. `tsx not installed` / `ERR_PNPM_IGNORED_BUILDS`
- **Fix**:
  ```bash
  ./scripts/setup_asset_generator.sh   # from dotfiles root (sync + pnpm install)
  # or manually:
  cd ~/.cursor/skills/asset-generator
  pnpm install
  pnpm approve-builds esbuild sharp   # once, if needed (pnpm-workspace allowBuilds usually enough)
  chmod +x ./run.sh
  ./run.sh --help
  ```

### 3. `[ITEMS ERROR] Cell count mismatch` or `Grid generation blocked`
- **Cause**: Missing `--confirm`, wrong cell count, or bad `--items` path.
- **Fix**: `cells.json` + `--items cells.json`. Run `--print-prompt` first, then `--confirm`.

### 4. Prefer file-based `--items`
- **Recommendation**: Always use `--items cells.json` (or `--items @cells.json`).
- Inline `'[...]'` can work on bash with careful quoting, but file paths are more reliable for agents.

### 5. Confirm token mismatch after dry-run
- **Cause**: CONFIRM TOKEN binds theme, cells, style, preset, refs, **`format`**, **`quality`** (default 80), and **`--out`** when set.
- **Fix**: Copy the **full** generate command from dry-run. Do not change `-f`, `-q`, `--out`, or `-r` between dry-run and `--confirm`.
- **Any flag change → re-run `--print-prompt`** and use the new token.
- Without `--out`, output goes to a random `Pictures/assets/.../asset_*` folder each run — **always pass `--out out/`** on dry-run and generate.
  ```bash
  ./run.sh --print-prompt -g 4 "Theme" --items cells.json -f png --out out
  ./run.sh --confirm <TOKEN> --grill-ack <ACK> -g 4 "Theme" --items cells.json -f png --out out
  ```

### 6. fal.ai 422 `image_urls` / `Field required` (edit with refs)
- **Symptom**: `genmedia run openai/gpt-image-2/edit` fails with Unprocessable Entity / `image_urls`.
- **Cause**: Edit endpoint requires CDN URLs from `genmedia upload` (this skill uploads refs automatically).
- **Fix**: Ensure refs exist on disk; re-run. Workaround: omit `-r` to use generate model.
- **Note**: 422, auth, and content-policy errors fail fast (no retry) to avoid wasted time/cost.

### 7. `[QUALITY GATE] JPEG output is blocked for --preset logo/wordmark`
- **Cause**: JPEG flattens transparency onto white — unsuitable for default logo/wordmark workflow.
- **Fix**: Use `-f webp` or `-f png`. Only use JPEG for logos with explicit `--allow-jpeg-logos`.

### 8. Logo crop shows fragments (`CIAL` instead of full wordmark)
- **Cause**: rembg leaves low-alpha glow; naive alpha bbox picks seam debris.
- **Fix**: Use `--preset logo` or `--tight` (chroma-key `#C0C0C0`/`#FF00FF` then largest-subject bbox).
- **Also**: `--no-rembg` + `--tight` if rembg eats blue/cyan glow.

### 9. Seam Detection & Bounding Boxes
- Primary: magenta `#FF00FF` grid line scan.
- Fallback: equal-split geometry (blocked unless `--allow-weak-seams`).
- Inspect: `./run.sh --inspect <outDir>` — target score ≥ 75/100.
- See `sheet.grid.json` for band coordinates.

### 10. Background Removal
- **Default (rembg on)**: ML background removal via genmedia (`pixelcut/background-removal`, fallback `fal-ai/birefnet`). Letterboxes to preserve aspect ratio — no stretch-fill.
- **`--no-rembg`**: Skips ML rembg; chroma-keys sheet `#C0C0C0` and `#FF00FF` to transparent instead. Use for blue/cyan glow logos where rembg eats the glow (`--no-rembg --tight`).
- **There is no keep-background mode for grids** — every grid cell is exported with transparency (rembg or chroma-key). Photo backgrounds or an intact gray sheet are not supported.

### 10b. Input validation (v2.3+)
- **Invalid `-g`**: Unknown grid strings (e.g. `-g 5`, `-g 2x5x3`) throw immediately — they no longer silently fall back to 1×1.
- **Unsupported hero aspect**: Single-shot `-a` ratios outside fal’s supported set throw at CLI parse time.
- **Duplicate cell `id`**: Same normalized id in `cells.json` throws before generation (filename slug collision).

### 10c. Auth preflight & `manifest.failed.json` (v2.3.3+)
Generation runs **auth preflight** (`assertGenmediaAuthReady`) immediately before paid genmedia calls — after dry-run/confirm gates, but **before** `generate` / `rembg`. Missing `FAL_KEY`, saved genmedia config, or `GENMEDIA_BIN` fails fast with no API spend. `--print-prompt` still works without auth (see §1).

On any pipeline failure after output dir creation, check **`manifest.failed.json`** in `--out` (never overwrites a successful `manifest.json`):

| When | `stage` (if set) | Extra fields |
|------|------------------|--------------|
| fal generate fails | `generate` | `batchId`, `error` |
| seam / magenta / chroma gates fail | `detect` | `batchId`, `error` |
| ML rembg fails | `rembg` | `batchId`, `error` |
| chroma-key path (`--no-rembg`) fails | `chroma-key` | `batchId`, `error` |
| pack aborts mid-batch | `pack` | `partialItems` (written cells so far) |

Re-run from `--print-prompt` after fixing the root cause; stale tokens if inputs/flags changed.

### 11. Output formats (webp / png / jpeg)
- **webp** (default): transparent logos/icons — preferred for LP assets.
- **png**: lossless transparency when webp is undesirable.
- **jpeg**: no alpha; flattened onto `#ffffff`. Not for `--preset logo/wordmark` unless `--allow-jpeg-logos`.
- Inspect verifies file bytes match `manifest.outputFormat`. JPEG alpha **requires** `sheet.transparent.png` + `sheet.grid.json` bands (manifest `alphaCoverage` is not used for scoring).

### 12. Custom Output Directory
- Astro projects: `src/assets/images/generated/<batch>/` for `<Image />` ingestion.
- Use a **directory** for grids (`--out out/`), not `--out batch.jpg` (that path is for single-hero only).
- Default without `--out`: `$XDG_PICTURES_DIR/assets/...` or `~/Pictures/assets/...`.

### 13. Post-generation validation
- **Automated**: `./run.sh --inspect out/batch` (no API call).
- **Manual**: `references/manual-validation.md` — human legibility checklist.

### 14. `Permission denied: ./run.sh`
- **Fix**: `chmod +x ~/.cursor/skills/asset-generator/run.sh`

### 15. Do not use `@fal-ai/client` / raw HTTP
- This skill shells out to `genmedia` (`upload`, `run --download --json`). If you see SDK imports creeping back in, remove them.
