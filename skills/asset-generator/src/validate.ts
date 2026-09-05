import sharp from 'sharp';
import { applyChromaKeyInPlace } from './chroma.js';
import { isMagentaPixel } from './grid-detect.js';
import type { GridMeta } from './types.js';

/** Inset from band edges when sampling cell interiors (SEAM_CLEAR_HALF + 3). */
const DEFAULT_INTERIOR_INSET_PX = 8;

export class PipelineValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'PipelineValidationError';
  }
}

function parseIntInRange(raw: string, min: number, max: number, label: string): number {
  const trimmed = raw.trim();
  if (!/^-?\d+$/.test(trimmed)) {
    throw new PipelineValidationError(`${label} must be an integer ${min}–${max}, got "${raw}".`);
  }
  const n = parseInt(trimmed, 10);
  if (n < min || n > max) {
    throw new PipelineValidationError(`${label} must be ${min}–${max}, got ${n}.`);
  }
  return n;
}

/** Transparent padding % inside square canvas (CLI -p / --pad). */
export function parsePadPercent(raw: string): number {
  return parseIntInRange(raw, 0, 50, 'Padding (--pad)');
}

/** Target output square size in px (CLI --size). */
export function parseOutputSizePx(raw: string): number {
  return parseIntInRange(raw, 16, 4096, 'Output size (--size)');
}

/** Ensure seam indices and band rectangles partition the sheet without overlap or inversion. */
export function validateGridGeometry(gridMeta: GridMeta): void {
  const [width, height] = gridMeta.srcSize;
  const { cols, rows, colSeams, rowSeams, bands } = gridMeta;

  if (cols < 1 || rows < 1) {
    throw new PipelineValidationError(
      `Invalid grid dimensions ${cols}x${rows}. Re-generate the sheet.`,
    );
  }

  const expectedBands = cols * rows;
  if (bands.length !== expectedBands) {
    throw new PipelineValidationError(
      `Grid band count mismatch: expected ${expectedBands} for ${cols}x${rows}, got ${bands.length}.\n` +
        'Seam detection may have desynced — inspect sheet.grid.json or re-generate with --mq high.',
    );
  }

  if (cols === 1 && rows === 1) {
    const band = bands[0];
    if (
      band.left !== 0 ||
      band.top !== 0 ||
      band.width !== width ||
      band.height !== height ||
      band.width < 1 ||
      band.height < 1
    ) {
      throw new PipelineValidationError(
        `Single-cell band does not cover the full sheet (${band.left},${band.top} ${band.width}x${band.height} vs ${width}x${height}).\n` +
          'Re-generate the sheet or inspect sheet.grid.json.',
      );
    }
    return;
  }

  const expectedColSeams = cols - 1;
  const expectedRowSeams = rows - 1;
  if (colSeams.length !== expectedColSeams) {
    throw new PipelineValidationError(
      `Expected ${expectedColSeams} column seam(s) for ${cols} columns, got ${colSeams.length}.\n` +
        'Grid geometry is inconsistent — re-generate with --mq high.',
    );
  }
  if (rowSeams.length !== expectedRowSeams) {
    throw new PipelineValidationError(
      `Expected ${expectedRowSeams} row seam(s) for ${rows} rows, got ${rowSeams.length}.\n` +
        'Grid geometry is inconsistent — re-generate with --mq high.',
    );
  }

  for (let i = 0; i < colSeams.length; i++) {
    const seam = colSeams[i];
    if (seam <= 0 || seam >= width) {
      throw new PipelineValidationError(
        `Column seam ${i + 1} at x=${seam} is outside (0, ${width}).\n` +
          'Seam landed on the image edge — re-generate with clearer #FF00FF dividers.',
      );
    }
    if (i > 0 && seam <= colSeams[i - 1]) {
      throw new PipelineValidationError(
        `Column seams are not strictly increasing: x=${colSeams[i - 1]} then x=${seam}.\n` +
          'Overlapping or inverted column boundaries — re-generate with --mq high.',
      );
    }
  }

  for (let i = 0; i < rowSeams.length; i++) {
    const seam = rowSeams[i];
    if (seam <= 0 || seam >= height) {
      throw new PipelineValidationError(
        `Row seam ${i + 1} at y=${seam} is outside (0, ${height}).\n` +
          'Seam landed on the image edge — re-generate with clearer #FF00FF dividers.',
      );
    }
    if (i > 0 && seam <= rowSeams[i - 1]) {
      throw new PipelineValidationError(
        `Row seams are not strictly increasing: y=${rowSeams[i - 1]} then y=${seam}.\n` +
          'Overlapping or inverted row boundaries — re-generate with --mq high.',
      );
    }
  }

  const colBounds = [0, ...colSeams, width];
  const rowBounds = [0, ...rowSeams, height];

  for (let c = 0; c < colBounds.length - 1; c++) {
    const w = colBounds[c + 1] - colBounds[c];
    if (w < 1) {
      throw new PipelineValidationError(
        `Column band ${c + 1} has width ${w}px (< 1). Column seams too close at x=${colBounds[c]}, x=${colBounds[c + 1]}.\n` +
          'Re-generate with --mq high or inspect sheet.grid.json.',
      );
    }
  }
  for (let r = 0; r < rowBounds.length - 1; r++) {
    const h = rowBounds[r + 1] - rowBounds[r];
    if (h < 1) {
      throw new PipelineValidationError(
        `Row band ${r + 1} has height ${h}px (< 1). Row seams too close at y=${rowBounds[r]}, y=${rowBounds[r + 1]}.\n` +
          'Re-generate with --mq high or inspect sheet.grid.json.',
      );
    }
  }

  const seen = new Set<number>();
  for (const band of bands) {
    if (band.width < 1 || band.height < 1) {
      throw new PipelineValidationError(
        `Band ${band.index + 1} [row=${band.row}, col=${band.col}] has invalid size ${band.width}x${band.height}px.\n` +
          'Crop region collapsed — re-generate with clearer grid dividers.',
      );
    }
    if (
      band.left < 0 ||
      band.top < 0 ||
      band.left + band.width > width ||
      band.top + band.height > height
    ) {
      throw new PipelineValidationError(
        `Band ${band.index + 1} [row=${band.row}, col=${band.col}] extends outside the sheet ` +
          `(${band.left},${band.top} ${band.width}x${band.height} vs ${width}x${height}).\n` +
          'Re-generate or inspect sheet.grid.json.',
      );
    }

    const expectedLeft = colBounds[band.col];
    const expectedTop = rowBounds[band.row];
    const expectedWidth = colBounds[band.col + 1] - expectedLeft;
    const expectedHeight = rowBounds[band.row + 1] - expectedTop;
    if (
      band.left !== expectedLeft ||
      band.top !== expectedTop ||
      band.width !== expectedWidth ||
      band.height !== expectedHeight
    ) {
      throw new PipelineValidationError(
        `Band ${band.index + 1} [row=${band.row}, col=${band.col}] does not match seam layout ` +
          `(got ${band.left},${band.top} ${band.width}x${band.height}, ` +
          `expected ${expectedLeft},${expectedTop} ${expectedWidth}x${expectedHeight}).\n` +
          'Bands overlap or gaps exist — re-generate with --mq high.',
      );
    }

    if (seen.has(band.index)) {
      throw new PipelineValidationError(
        `Duplicate band index ${band.index}. Grid metadata is corrupt — re-generate the sheet.`,
      );
    }
    seen.add(band.index);
  }
}

export function validateGridSeams(
  gridMeta: GridMeta,
  options: { allowWeakSeams?: boolean } = {},
): void {
  validateGridGeometry(gridMeta);

  if (gridMeta.cols === 1 && gridMeta.rows === 1) {
    return;
  }

  if (gridMeta.detector === 'magenta') {
    return;
  }

  if (options.allowWeakSeams) {
    return;
  }

  const conf = gridMeta.seamConfidence;
  const detail = conf
    ? `col=[${conf.col.map((v) => v.toFixed(2)).join(',')}] row=[${conf.row.map((v) => v.toFixed(2)).join(',')}]`
    : `detector=${gridMeta.detector}`;

  throw new PipelineValidationError(
    `Grid seam detection unreliable (${detail}).\n` +
      'The sheet likely lacks clear #FF00FF divider lines — cell boundaries may be wrong.\n' +
      'Re-generate with --mq high, or pass --allow-weak-seams to proceed anyway.',
  );
}

/** Reject sheets where magenta cell subjects could fool seam detection. */
export async function validateNoMagentaSubjectCollision(
  imagePath: string,
  gridMeta: GridMeta,
  options: { maxInteriorMagenta?: number; insetPx?: number } = {},
): Promise<void> {
  if (gridMeta.cols === 1 && gridMeta.rows === 1) {
    return;
  }

  const maxInteriorMagenta = options.maxInteriorMagenta ?? 0.08;
  const insetPx = options.insetPx ?? DEFAULT_INTERIOR_INSET_PX;

  const image = sharp(imagePath);
  const metadata = await image.metadata();
  const width = metadata.width!;
  const height = metadata.height!;
  const channels = metadata.channels || 3;
  const rawBuffer = await image.raw().toBuffer();

  for (const band of gridMeta.bands) {
    const left = band.left + insetPx;
    const right = band.left + band.width - insetPx;
    const top = band.top + insetPx;
    const bottom = band.top + band.height - insetPx;

    if (left >= right || top >= bottom) {
      continue;
    }

    let magentaCount = 0;
    let total = 0;

    for (let y = top; y < bottom; y++) {
      for (let x = left; x < right; x++) {
        const idx = (y * width + x) * channels;
        if (isMagentaPixel(rawBuffer[idx], rawBuffer[idx + 1], rawBuffer[idx + 2])) {
          magentaCount++;
        }
        total++;
      }
    }

    const ratio = magentaCount / total;
    if (ratio > maxInteriorMagenta) {
      throw new PipelineValidationError(
        `Cell ${band.index + 1} [row=${band.row}, col=${band.col}] interior contains ${(ratio * 100).toFixed(1)}% magenta pixels (max ${(maxInteriorMagenta * 100).toFixed(0)}%).\n` +
          'Magenta/neon (#FF00FF-like) cell subjects collide with grid seam detection — boundaries may split wrong.\n' +
          'Re-generate without magenta fills in cell subjects; use non-magenta brand colors instead.\n' +
          '--allow-weak-seams does not bypass this check.',
      );
    }
  }
}

/** Preflight chroma-key: reject cells whose subject would be keyed away (near-gray subjects). */
export async function validateChromaKeyLeavesSubject(
  imagePath: string,
  gridMeta: GridMeta,
  options: { minCoverage?: number; insetPx?: number } = {},
): Promise<void> {
  const minCoverage = options.minCoverage ?? 0.02;
  const insetPx = options.insetPx ?? DEFAULT_INTERIOR_INSET_PX;

  const image = sharp(imagePath);
  const metadata = await image.metadata();
  const width = metadata.width!;
  const height = metadata.height!;
  const rawBuffer = Buffer.from(await image.ensureAlpha().raw().toBuffer());

  for (const band of gridMeta.bands) {
    const left = band.left + insetPx;
    const right = band.left + band.width - insetPx;
    const top = band.top + insetPx;
    const bottom = band.top + band.height - insetPx;

    if (left >= right || top >= bottom) {
      continue;
    }

    const regionW = right - left;
    const regionH = bottom - top;
    const region = Buffer.alloc(regionW * regionH * 4);

    for (let y = top; y < bottom; y++) {
      for (let x = left; x < right; x++) {
        const srcIdx = (y * width + x) * 4;
        const dstIdx = ((y - top) * regionW + (x - left)) * 4;
        region[dstIdx] = rawBuffer[srcIdx];
        region[dstIdx + 1] = rawBuffer[srcIdx + 1];
        region[dstIdx + 2] = rawBuffer[srcIdx + 2];
        region[dstIdx + 3] = rawBuffer[srcIdx + 3];
      }
    }

    applyChromaKeyInPlace(region, regionW, regionH);

    let opaque = 0;
    const total = regionW * regionH;
    for (let i = 0; i < total; i++) {
      if (region[i * 4 + 3] > 15) opaque++;
    }

    const coverage = opaque / total;
    if (coverage < minCoverage) {
      throw new PipelineValidationError(
        `Cell ${band.index + 1} [row=${band.row}, col=${band.col}] would lose its subject after chroma-key ` +
          `(${(coverage * 100).toFixed(2)}% opaque, min ${(minCoverage * 100).toFixed(0)}%).\n` +
          'Gray or near-gray (#C0C0C0-like) cell subjects collide with chroma-key background removal.\n' +
          'Re-generate with a non-gray subject color, use rembg without --tight, or recolor the subject.',
      );
    }
  }
}

export async function measureAlphaCoverage(imageBuffer: Buffer): Promise<number> {
  const image = sharp(imageBuffer);
  const meta = await image.metadata();
  const w = meta.width!;
  const h = meta.height!;
  const raw = await image.ensureAlpha().raw().toBuffer();

  let opaque = 0;
  const total = w * h;
  for (let i = 0; i < total; i++) {
    if (raw[i * 4 + 3] > 15) opaque++;
  }
  return opaque / total;
}

export async function validateCellAlphaCoverage(
  imageBuffer: Buffer,
  label: string,
  index: number,
  options: { minCoverage?: number; allowEmptyCells?: boolean } = {},
): Promise<number> {
  const minCoverage = options.minCoverage ?? 0.02;
  const coverage = await measureAlphaCoverage(imageBuffer);

  if (!options.allowEmptyCells && coverage < minCoverage) {
    throw new PipelineValidationError(
      `Cell ${index + 1} (${label}) failed quality gate: ${(coverage * 100).toFixed(2)}% opaque pixels (min ${(minCoverage * 100).toFixed(0)}%).\n` +
        'Likely empty crop, rembg ate the subject, or bbox picked seam debris. Try --no-rembg --tight or re-generate.',
    );
  }

  return coverage;
}

export function validateCellDimensions(
  width: number,
  height: number,
  label: string,
  index: number,
  minPx: number = 32,
): void {
  if (width < minPx || height < minPx) {
    throw new PipelineValidationError(
      `Cell ${index + 1} (${label}) failed dimension gate: ${width}x${height}px (min ${minPx}px per side).\n` +
        'Crop too aggressive or seam misalignment — try --allow-weak-seams off and re-generate with --mq high.',
    );
  }
}
