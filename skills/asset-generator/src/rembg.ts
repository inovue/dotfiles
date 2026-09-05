import fs from 'node:fs';
import sharp from 'sharp';
import {
  ensureGenmediaAvailable,
  genmediaRunDownload,
  genmediaUpload,
  requireFalKey,
  withRetry,
} from './genmedia.js';

export const PIXELCUT_MODEL = 'pixelcut/background-removal';
export const BIREFNET_MODEL = 'fal-ai/birefnet';

const TRANSPARENT = { r: 0, g: 0, b: 0, alpha: 0 } as const;

/** Letterbox/pad with transparency to exact size — never stretch (no fit: 'fill'). */
export async function fitTransparentToSize(
  imageBuffer: Buffer,
  targetWidth: number,
  targetHeight: number,
): Promise<Buffer> {
  const meta = await sharp(imageBuffer).metadata();
  if (meta.width === targetWidth && meta.height === targetHeight) {
    return imageBuffer;
  }

  return sharp(imageBuffer)
    .ensureAlpha()
    .resize(targetWidth, targetHeight, {
      fit: 'contain',
      background: TRANSPARENT,
    })
    .png()
    .toBuffer();
}

export async function removeBackground(
  imagePath: string,
  destPath: string,
): Promise<string> {
  requireFalKey();
  ensureGenmediaAvailable();

  console.log('\x1b[36m⬆ Uploading sheet via genmedia upload...\x1b[0m');
  const imageUrl = await genmediaUpload(imagePath);

  console.log(`\x1b[36m⚡ genmedia run ${PIXELCUT_MODEL}...\x1b[0m`);

  try {
    await withRetry(async () => {
      await genmediaRunDownload(
        PIXELCUT_MODEL,
        {
          image_url: imageUrl,
          output_format: 'rgba',
        },
        destPath,
      );
    }, `Background Removal (${PIXELCUT_MODEL})`);
  } catch (err: any) {
    console.warn(`\x1b[33m[WARN] ${PIXELCUT_MODEL} failed, trying fallback to ${BIREFNET_MODEL}...\x1b[0m`);
    await withRetry(async () => {
      await genmediaRunDownload(
        BIREFNET_MODEL,
        {
          image_url: imageUrl,
        },
        destPath,
      );
    }, `Background Removal Fallback (${BIREFNET_MODEL})`);
  }

  // Ensure dimension matches original source without aspect distortion
  const srcMeta = await sharp(imagePath).metadata();
  const destMeta = await sharp(destPath).metadata();
  if (
    srcMeta.width &&
    srcMeta.height &&
    (destMeta.width !== srcMeta.width || destMeta.height !== srcMeta.height)
  ) {
    const fitted = await fitTransparentToSize(
      fs.readFileSync(destPath),
      srcMeta.width,
      srcMeta.height,
    );
    fs.writeFileSync(destPath, fitted);
  }

  return destPath;
}
