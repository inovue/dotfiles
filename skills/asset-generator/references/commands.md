# asset-generator — command examples

Always run from `$HOME/.cursor/skills/asset-generator` via `./run.sh` (never `npx tsx`).

Dry-run and `--confirm` must use **identical** flags (including `--out`).

```bash
skill="$HOME/.cursor/skills/asset-generator"
cd "$skill"

# Dry-run
./run.sh --print-prompt -g 4 "Financial Fantasy Logos" -s flat \
  --items cells.json --out src/assets/images/generated/logos

# With refs (user-requested only)
./run.sh --print-prompt -g 4 "Financial Fantasy Logos" -s flat \
  --items cells.json -r ../public/favicon.svg -m style \
  --out src/assets/images/generated/logos

# Generate — paste token; flags must match dry-run
./run.sh --confirm abc123def456 --grill-ack <GRILL_ACK> --preset logo -g 4 "Financial Fantasy Logos" -s flat \
  --items cells.json -r ../public/favicon.svg -m style \
  -f png --out src/assets/images/generated/logos

# Blue/cyan logos — chroma-key only
./run.sh --confirm <TOKEN> --grill-ack <GRILL_ACK> -g 4 "Logos" --no-rembg --tight \
  --items cells.json --out out

# Horizontal wordmarks — 4x2
./run.sh --print-prompt -g 4x2 "Brand Wordmarks" --preset wordmark --items cells-8.json --out out
./run.sh --confirm <TOKEN> --grill-ack <GRILL_ACK> -g 4x2 "Brand Wordmarks" --preset wordmark \
  --items cells-8.json --out out

# Single hero
./run.sh --print-prompt "AI Workspace" -s glass -a 16:9 -l right-heavy --out hero.webp
./run.sh --confirm <TOKEN> "AI Workspace" -s glass -a 16:9 -l right-heavy --out hero.webp

# Post-generation validation (no API)
./run.sh --inspect out
```
