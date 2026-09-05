#!/usr/bin/env node
import { STYLE_PRESETS, resolveStyle } from './presets.js';
import type { AspectRatio, CompositionLayout, GeneratorOptions, ModelQuality, ReferenceMode } from './types.js';
import { DEFAULT_MODEL_QUALITY } from './types.js';
import { runAssetGenerator } from './engine.js';
import { ItemsParseError } from './items.js';
import { inspectBatch, formatInspectReport } from './inspect.js';
import { parseOutputFormat, clampEncodingQuality } from './format.js';
import { aspectToFalSize } from './fal.js';
import { parseGridCount } from './prompt.js';
import { parseOutputSizePx, parsePadPercent, PipelineValidationError } from './validate.js';

export class CliParseError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'CliParseError';
  }
}

function cliFail(message: string): never {
  throw new CliParseError(message);
}

function requireFlagValue(args: string[], index: number, flag: string): string {
  const val = args[index];
  if (val === undefined || val.startsWith('-')) {
    cliFail(`Option ${flag} requires a value.`);
  }
  return val;
}

function printHelp(): void {
  console.log(`
\x1b[1mAsset Generator CLI (Agent-Optimized LP Asset Pipeline)\x1b[0m

\x1b[33mUsage:\x1b[0m
  ./run.sh [options] [prompt]
  # or: node <skill-dir>/node_modules/tsx/dist/cli.mjs <skill-dir>/src/cli.ts [options] [prompt]

\x1b[33mQuick Examples:\x1b[0m
  # Grid batch — prefer cells.json file (stable quoting on bash)
  cli.ts -g 4 "AI SaaS Core Features" -s clay -p 10 -o src/assets/images/features --items cells.json

  # Logo preset (sets --mq high --tight)
  cli.ts --preset logo --confirm <token> -g 4 "Brand" --items cells.json -o out

  # Allow weak/missing magenta seams (not recommended)
  cli.ts --allow-weak-seams --confirm <token> -g 4 "Theme" --items cells.json

  # Character Mascot Reference (4 poses)
  cli.ts -g 4 "Mascot Feature Set" -r ./mascot.png -m character -s clay -o src/assets/images/features

  # Single Hero Visual with layout & filename target
  cli.ts "AI Workspace Platform" -s glass -a 16:9 -l right-heavy -o src/assets/images/hero.webp

\x1b[33mOptions (all support 1-letter flags):\x1b[0m
  -g, --grid <4|9|16|NxM>    Grid: 4 (2x2), 9 (3x3), 16 (4x4), 2x4, 1 (single)
  -s, --style <name>          Style preset (clay, glossy, glass, flat, iso, neon, badge, etc.)
  -a, --aspect <ratio>        Aspect ratio for 1-shot (1:1, 16:9, 9:16, 4:3, 3:4); grids must stay 1:1
  -l, --layout <name>         UI composition (right-heavy, left-heavy, centered, wide-isometric)
  -p, --pad <0-50>            Transparent padding % inside square canvas (default: 10)
  -r, --ref <path...>         Reference image(s) for character/style anchoring (max 3)
  -m, --ref-mode <mode>       Reference interpretation mode: character | style | auto (default: auto)
  --mq, --model-quality <q>   gpt-image-2 render quality: low | medium (default) | high
  -o, --out <path>            Output directory or specific image file path
  -f, --format <fmt>          Cell output format: webp (default) | png | jpeg | jpg
  -q, --quality <1-100>       Encoding quality for webp/png/jpeg (default: 80)
  -k, --2k                    Generate at 2048x2048 high resolution
  -j, --json                  Output machine-readable manifest JSON to stdout
  --size <px>                 Target output square size (e.g. 512, 256)
  --items <@file|json>        Cell specs: cells.json file (required for grids)
  --confirm <token>           Token from --print-prompt CONFIRM TOKEN line
  --grill-ack <token>         GRILL_ACK from --print-prompt (checklist completed)
  --preset <logo|wordmark|icon> logo/wordmark: --mq high --tight
  --allow-weak-seams          Proceed when magenta seam detection is unreliable
  --allow-empty-cells         Skip per-cell alpha coverage gate
  --tight                     Tight crop: chroma-key #C0C0C0/#FF00FF then largest subject bbox
  --raw-cell                  Keep raw cell bounds without trimming
  --no-rembg                  Disable background removal
  --allow-jpeg-logos          Allow -f jpeg with --preset logo/wordmark (flattened white bg)
  --print-prompt              Print the generated prompt and exit
  --inspect <dir>             Validate existing batch (manifest + files); no API call
  --list-styles               List all 14 available style presets
  -h, --help                  Show this help message
`);
}

function printStyles(): void {
  console.log('\x1b[1mAvailable Style Presets:\x1b[0m\n');
  for (const [id, preset] of Object.entries(STYLE_PRESETS)) {
    const aliasStr = preset.aliases.length > 0 ? ` (${preset.aliases.join(', ')})` : '';
    console.log(`  \x1b[36m${id}\x1b[0m${aliasStr}`);
    console.log(`    ${preset.name}: ${preset.description}\n`);
  }
}

export function parseArgs(args: string[]): GeneratorOptions {
  const options: GeneratorOptions = {
    prompt: '',
    rembg: true,
    refImages: [],
    modelQuality: DEFAULT_MODEL_QUALITY,
  };

  const positional: string[] = [];

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];

    if (arg === '-h' || arg === '--help') {
      printHelp();
      process.exit(0);
    }
    if (arg === '--list-styles') {
      printStyles();
      process.exit(0);
    }
    if (arg === '--inspect') {
      options.inspectDir = requireFlagValue(args, ++i, '--inspect');
      continue;
    }
    if (arg === '--allow-jpeg-logos') {
      options.allowJpegLogos = true;
      continue;
    }
    if (arg === '--print-prompt') {
      options.printPrompt = true;
      continue;
    }
    if (arg === '--grill-ack') {
      options.grillAck = requireFlagValue(args, ++i, '--grill-ack');
      continue;
    }
    if (arg === '--skip-grill-ack') {
      options.skipGrillAck = true;
      continue;
    }
    if (arg === '--confirm') {
      options.confirmToken = requireFlagValue(args, ++i, '--confirm');
      continue;
    }
    if (arg === '--allow-weak-seams') {
      options.allowWeakSeams = true;
      continue;
    }
    if (arg === '--allow-empty-cells') {
      options.allowEmptyCells = true;
      continue;
    }
    if (arg === '--preset') {
      const preset = requireFlagValue(args, ++i, '--preset').toLowerCase();
      if (preset === 'logo' || preset === 'wordmark') {
        options.preset = preset;
        options.modelQuality = 'high';
        options.tight = true;
      } else if (preset === 'icon') {
        options.preset = 'icon';
        options.modelQuality = 'medium';
      } else {
        cliFail(`Unknown preset "${preset}". Use logo, wordmark, or icon.`);
      }
      continue;
    }
    if (arg === '-j' || arg === '--json') {
      options.jsonOutput = true;
      continue;
    }
    if (arg === '--no-rembg') {
      options.rembg = false;
      continue;
    }
    if (arg === '-k' || arg === '--2k') {
      options.is2k = true;
      continue;
    }
    if (arg === '--tight') {
      options.tight = true;
      continue;
    }
    if (arg === '--raw-cell') {
      options.rawCell = true;
      continue;
    }
    if (arg === '-g' || arg === '--grid') {
      const raw = requireFlagValue(args, ++i, arg);
      parseGridCount(raw);
      options.countOrGrid = raw;
      continue;
    }
    if (arg === '-s' || arg === '--style') {
      const raw = requireFlagValue(args, ++i, arg);
      if (!resolveStyle(raw)) {
        cliFail(`Unknown style "${raw}". Use --list-styles to see presets.`);
      }
      options.style = raw;
      continue;
    }
    if (arg === '-a' || arg === '--aspect') {
      options.aspect = requireFlagValue(args, ++i, arg) as AspectRatio;
      continue;
    }
    if (arg === '-l' || arg === '--layout' || arg === '--composition') {
      options.composition = requireFlagValue(args, ++i, arg) as CompositionLayout;
      continue;
    }
    if (arg === '-p' || arg === '--pad') {
      options.pad = parsePadPercent(requireFlagValue(args, ++i, arg));
      continue;
    }
    if (arg === '-r' || arg === '--ref') {
      const val = requireFlagValue(args, ++i, arg);
      const split = val.split(',').map((s) => s.trim()).filter(Boolean);
      options.refImages?.push(...split);
      continue;
    }
    if (arg === '-m' || arg === '--ref-mode') {
      const mode = requireFlagValue(args, ++i, arg).toLowerCase();
      if (mode === 'character' || mode === 'chara' || mode === 'char') {
        options.refMode = 'character';
      } else if (mode === 'style' || mode === 'art') {
        options.refMode = 'style';
      } else if (mode === 'auto') {
        options.refMode = 'auto';
      } else {
        cliFail(`Unknown ref mode "${mode}". Use character, style, or auto.`);
      }
      continue;
    }
    if (arg === '--mq' || arg === '--model-quality') {
      const q = requireFlagValue(args, ++i, arg).toLowerCase() as ModelQuality;
      if (q !== 'high' && q !== 'medium' && q !== 'low') {
        cliFail(`Unknown model quality "${q}". Use low, medium, or high.`);
      }
      options.modelQuality = q;
      continue;
    }
    if (arg === '-o' || arg === '--out' || arg === '--output-dir') {
      options.outDir = requireFlagValue(args, ++i, arg);
      continue;
    }
    if (arg === '-f' || arg === '--format') {
      const raw = requireFlagValue(args, ++i, arg);
      const parsed = parseOutputFormat(raw);
      if (!parsed) {
        cliFail(`Invalid format "${raw}". Use webp, png, jpeg, or jpg.`);
      }
      options.format = parsed;
      continue;
    }
    if (arg === '-q' || arg === '--quality') {
      const raw = requireFlagValue(args, ++i, arg);
      const parsed = parseInt(raw, 10);
      if (!Number.isFinite(parsed)) {
        cliFail(`Invalid quality "${raw}". Use an integer 1–100.`);
      }
      options.quality = clampEncodingQuality(parsed);
      continue;
    }
    if (arg === '--size') {
      options.size = parseOutputSizePx(requireFlagValue(args, ++i, '--size'));
      continue;
    }
    if (arg === '--items') {
      options.itemsRaw = requireFlagValue(args, ++i, '--items');
      continue;
    }

    if (arg.startsWith('-')) {
      cliFail(`Unknown option "${arg}". Pass -h for help.`);
    }

    positional.push(arg);
  }

  const gridPatterns = ['1', '4', '9', '16', '1x1', '2x2', '3x3', '4x4', 'single'];
  if (!options.countOrGrid && positional.length > 0) {
    const head = positional[0].toLowerCase();
    if (gridPatterns.includes(head) || /^\d+x\d+$/.test(head)) {
      parseGridCount(positional[0]);
      options.countOrGrid = positional[0];
      options.prompt = positional.slice(1).join(' ');
    } else {
      options.prompt = positional.join(' ');
    }
  } else {
    options.prompt = positional.join(' ');
  }

  const gridInfo = parseGridCount(options.countOrGrid);

  if (options.tight && options.rawCell) {
    cliFail('Cannot combine --tight and --raw-cell (conflicting framing). Pick one.');
  }

  if (options.pad != null && (options.tight || options.rawCell)) {
    console.warn('[WARN] --pad is ignored when using --tight or --raw-cell.');
  }
  if (options.size != null && options.rawCell) {
    console.warn('[WARN] --size is ignored when using --raw-cell.');
  }

  if (gridInfo.total > 1) {
    if (options.aspect && options.aspect !== '1:1') {
      cliFail(
        `Grid batches require a square sheet (1:1). Drop -a/--aspect or use a single hero image instead of -g ${options.countOrGrid}.`,
      );
    }
    if (options.composition) {
      console.warn('[WARN] --layout is ignored for grid batches.');
    }
  }

  if (options.aspect) {
    aspectToFalSize(options.aspect, options.is2k);
  }

  return options;
}

async function main() {
  const args = process.argv.slice(2);
  let options: GeneratorOptions;
  try {
    options = parseArgs(args);
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    console.error(`\x1b[31mError: ${message}\x1b[0m`);
    process.exit(1);
  }

  if (!options.prompt && !options.itemsRaw && !options.printPrompt && !options.inspectDir) {
    console.error('\x1b[31mError: Prompt is required (theme/context string).\x1b[0m');
    printHelp();
    process.exit(1);
  }

  if (options.inspectDir) {
    try {
      const result = await inspectBatch(options.inspectDir, {
        allowWeakSeams: options.allowWeakSeams,
        allowEmptyCells: options.allowEmptyCells,
        json: options.jsonOutput,
      });
      if (options.jsonOutput) {
        console.log(JSON.stringify(result, null, 2));
      } else {
        console.log(formatInspectReport(result));
      }
      process.exit(result.ok ? 0 : 1);
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : String(err);
      console.error(`\x1b[31m[INSPECT ERROR] ${message}\x1b[0m`);
      process.exit(1);
    }
  }

  try {
    await runAssetGenerator(options);
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    if (err instanceof ItemsParseError) {
      console.error(`\x1b[31m[ITEMS ERROR] ${message}\x1b[0m`);
    } else if (err instanceof PipelineValidationError) {
      console.error(`\x1b[31m[QUALITY GATE] ${message}\x1b[0m`);
    } else {
      console.error(`\x1b[31mError: ${message}\x1b[0m`);
    }
    process.exit(1);
  }
}

if (process.argv[1]?.endsWith('cli.ts') || process.argv[1]?.endsWith('cli.js')) {
  main();
}
