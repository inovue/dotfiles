import fs from 'node:fs';
import type { AspectRatio, GeneratorOptions } from './types.js';
import { DEFAULT_MODEL_QUALITY } from './types.js';
import {
  ensureGenmediaAvailable,
  genmediaRunDownload,
  genmediaUpload,
  requireFalKey,
  withRetry,
} from './genmedia.js';
import { PipelineValidationError } from './validate.js';

export const GPT_IMAGE_GENERATE_MODEL = 'openai/gpt-image-2';
export const GPT_IMAGE_EDIT_MODEL = 'openai/gpt-image-2/edit';
export const MAX_REFERENCE_IMAGES = 3;
export { MAX_RETRIES, requireFalKey, withRetry } from './genmedia.js';

const FAL_SUPPORTED_ASPECTS = ['1:1', '16:9', '9:16', '4:3', '3:4'] as const;
const FAL_UNSUPPORTED_ASPECTS = ['3:2', '2:3', '21:9'] as const;

export function aspectToFalSize(aspect?: AspectRatio, is2k?: boolean): string | { width: number; height: number } {
  if (is2k && (!aspect || aspect === '1:1')) {
    return { width: 2048, height: 2048 };
  }

  if (!aspect || aspect === '1:1') {
    return is2k ? { width: 2048, height: 2048 } : 'square_hd';
  }

  if ((FAL_UNSUPPORTED_ASPECTS as readonly string[]).includes(aspect)) {
    throw new PipelineValidationError(
      `Unsupported aspect ratio "${aspect}" for fal image generation. Supported: ${FAL_SUPPORTED_ASPECTS.join(', ')}.`,
    );
  }

  switch (aspect) {
    case '16:9':
      return 'landscape_16_9';
    case '9:16':
      return 'portrait_16_9';
    case '4:3':
      return 'landscape_4_3';
    case '3:4':
      return 'portrait_4_3';
    default:
      throw new PipelineValidationError(
        `Unknown aspect ratio "${aspect}". Supported: ${FAL_SUPPORTED_ASPECTS.join(', ')}.`,
      );
  }
}

/** Build fal.ai request payload (exported for unit tests). Ref paths are local until upload. */
export function buildFalImageInput(
  prompt: string,
  options: GeneratorOptions,
): { modelId: string; input: Record<string, unknown>; refPaths: string[]; refCount: number } {
  const imageSize = aspectToFalSize(options.aspect, options.is2k);
  const refPaths = (options.refImages || [])
    .map((p) => p.trim())
    .filter((p) => p && fs.existsSync(p))
    .slice(0, MAX_REFERENCE_IMAGES);
  const hasRefs = refPaths.length > 0;

  const modelId = hasRefs ? GPT_IMAGE_EDIT_MODEL : GPT_IMAGE_GENERATE_MODEL;
  const quality = options.modelQuality || DEFAULT_MODEL_QUALITY;

  const input: Record<string, unknown> = {
    prompt,
    image_size: imageSize,
    quality,
    num_images: 1,
    output_format: 'png',
  };

  return { modelId, input, refPaths, refCount: refPaths.length };
}

export async function generateFalImage(
  prompt: string,
  destPath: string,
  options: GeneratorOptions,
): Promise<string> {
  requireFalKey();
  ensureGenmediaAvailable();

  const { modelId, input, refPaths, refCount } = buildFalImageInput(prompt, options);
  const quality = (input.quality as string) || DEFAULT_MODEL_QUALITY;

  if (refCount > 0) {
    console.log(`\x1b[36m📎 Attached ${refCount} reference image(s) (Mode: ${options.refMode || 'auto'})\x1b[0m`);
    console.log('\x1b[36m⬆ Uploading reference(s) via genmedia upload...\x1b[0m');
    const urls: string[] = [];
    for (const ref of refPaths) {
      urls.push(await genmediaUpload(ref));
    }
    // gpt-image-2/edit requires image_urls (array)
    input.image_urls = urls;
  }

  console.log(`\x1b[36m⚡ genmedia run ${modelId} (quality: ${quality})...\x1b[0m`);

  await withRetry(async () => {
    await genmediaRunDownload(modelId, input, destPath);
  }, `Image Generation (${modelId})`);

  return destPath;
}
