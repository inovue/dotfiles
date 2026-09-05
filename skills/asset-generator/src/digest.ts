import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import type { CellSpec, GeneratorOptions } from './types.js';
import { DEFAULT_MODEL_QUALITY } from './types.js';

/** Resolve existing ref paths so relative vs absolute cwd forms bind the same token. */
function normalizeRefForDigest(refPath: string): string {
  const trimmed = refPath.trim();
  if (!trimmed) return trimmed;
  if (fs.existsSync(trimmed)) {
    return path.resolve(trimmed).replace(/\\/g, '/');
  }
  return trimmed.replace(/\\/g, '/');
}

/** Stable 12-char token binding theme + cells + key render flags. */
export function computeBatchDigest(
  gridTotal: number,
  theme: string,
  cellSpecs: CellSpec[],
  options: Pick<GeneratorOptions, 'style' | 'countOrGrid' | 'modelQuality' | 'tight' | 'rembg' | 'refImages' | 'refMode' | 'aspect' | 'composition' | 'preset' | 'format' | 'quality' | 'outDirResolved'>,
): string {
  const payload = JSON.stringify({
    grid: options.countOrGrid ?? String(gridTotal),
    theme: theme.trim(),
    cells: cellSpecs.map((c) => ({ id: c.id ?? null, prompt: c.prompt })),
    style: options.style ?? null,
    aspect: options.aspect ?? '1:1',
    composition: options.composition ?? null,
    preset: options.preset ?? null,
    mq: options.modelQuality ?? DEFAULT_MODEL_QUALITY,
    tight: !!options.tight,
    rembg: options.rembg !== false,
    refs: (options.refImages ?? []).map(normalizeRefForDigest),
    refMode: options.refMode ?? null,
    format: options.format ?? 'webp',
    quality: options.quality ?? 80,
    out: options.outDirResolved ?? null,
  });
  return crypto.createHash('sha256').update(payload).digest('hex').slice(0, 12);
}

/** Grill checklist ack — derived from confirm token; proves agent read dry-run output. */
export function computeGrillAckToken(confirmToken: string): string {
  return crypto.createHash('sha256').update(`grill:${confirmToken}`).digest('hex').slice(0, 12);
}
