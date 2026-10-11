import {
  S3Client,
  CreateBucketCommand,
  HeadBucketCommand,
  ListMultipartUploadsCommand,
  CreateMultipartUploadCommand,
  ListPartsCommand,
  UploadPartCommand,
  CompleteMultipartUploadCommand,
  HeadObjectCommand,
  GetObjectCommand,
  PutObjectCommand,
  DeleteObjectCommand,
  AbortMultipartUploadCommand,
} from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";
import { createHash } from "node:crypto";
import sharp from "sharp";
import { APIError } from "./domain.js";
export const bucket = process.env.S3_BUCKET ?? "slate-private";
export const s3 = new S3Client({
  endpoint: process.env.S3_ENDPOINT ?? "http://localhost:9000",
  region: process.env.S3_REGION ?? "us-east-1",
  forcePathStyle: true,
  credentials: {
    accessKeyId: process.env.S3_ACCESS_KEY ?? "slate_minio",
    secretAccessKey: process.env.S3_SECRET_KEY ?? "slate_minio_dev_password",
  },
});
export async function initStorage() {
  try {
    await s3.send(new HeadBucketCommand({ Bucket: bucket }));
  } catch (error: any) {
    if (error.$metadata?.httpStatusCode !== 404) throw error;
    await s3.send(new CreateBucketCommand({ Bucket: bucket }));
  }

}
export async function startUpload(key: string, mime: string) {
  await initStorage();
  return (
    await s3.send(
      new CreateMultipartUploadCommand({
        Bucket: bucket,
        Key: key,
        ContentType: mime,
      }),
    )
  ).UploadId!;
}
export async function parts(key: string, uploadId: string) {
  const result: {
    partNumber: number;
    sizeBytes: number;
    storageETag: string;
  }[] = [];
  let marker: string | undefined;
  do {
    const r = await s3.send(
      new ListPartsCommand({
        Bucket: bucket,
        Key: key,
        UploadId: uploadId,
        PartNumberMarker: marker,
      }),
    );
    for (const p of r.Parts ?? [])
      result.push({
        partNumber: p.PartNumber!,
        sizeBytes: p.Size!,
        storageETag: p.ETag!,
      });
    marker = r.IsTruncated ? r.NextPartNumberMarker : undefined;
  } while (marker);
  return result.sort((a, b) => a.partNumber - b.partNumber);
}
export const signPart = (key: string, uploadId: string, number: number) =>
  getSignedUrl(
    s3,
    new UploadPartCommand({
      Bucket: bucket,
      Key: key,
      UploadId: uploadId,
      PartNumber: number,
    }),
    { expiresIn: 900 },
  );
export const signDownload = (key: string, filename?: string) =>
  getSignedUrl(
    s3,
    new GetObjectCommand({
      Bucket: bucket,
      Key: key,
      ResponseCacheControl: "private, no-store",
      ResponseContentDisposition: filename
        ? `attachment; filename*=UTF-8''${encodeURIComponent(filename)}`
        : undefined,
    }),
    { expiresIn: 60 },
  );
export async function exists(key: string) {
  try {
    return await s3.send(new HeadObjectCommand({ Bucket: bucket, Key: key }));
  } catch (error: any) {
    if (error.$metadata?.httpStatusCode === 404) return undefined;
    throw error;
  }
}
export async function finish(
  key: string,
  uploadId: string,
  uploaded: Awaited<ReturnType<typeof parts>>,
) {
  await s3.send(
    new CompleteMultipartUploadCommand({
      Bucket: bucket,
      Key: key,
      UploadId: uploadId,
      MultipartUpload: {
        Parts: uploaded.map((p) => ({
          PartNumber: p.partNumber,
          ETag: p.storageETag,
        })),
      },
    }),
  );
}
export async function verify(
  key: string,
  expected: string,
  size: number,
  mime: string,
) {
  const r = await s3.send(new GetObjectCommand({ Bucket: bucket, Key: key }));
  if (!r.Body) throw new Error("Storage returned no body");
  const digest = createHash("sha256");
  let length = 0;
  const image =
    [
      "image/jpeg",
      "image/png",
      "image/webp",
      "image/heic",
      "image/heif",
    ].includes(mime) && size <= 20 * 1024 * 1024;
  const chunks: Buffer[] = [];
  let header = Buffer.alloc(0);
  for await (const chunk of r.Body as AsyncIterable<Uint8Array>) {
    const bytes = Buffer.from(chunk);
    length += bytes.length;
    if (length > size)
      throw new APIError(422, "Stored file exceeds declared size");
    digest.update(bytes);
    if (header.length < 64)
      header = Buffer.concat([header, bytes.subarray(0, 64 - header.length)]);
    if (image) chunks.push(bytes);
  }
  if (length !== size || digest.digest("hex") !== expected)
    throw new APIError(422, "SHA256 or byte count mismatch");
  const ftyp = header.subarray(4, 8).toString() === "ftyp";
  const brand = header.subarray(8, 12).toString();
  const validMime =
    mime === "image/jpeg"
      ? header.subarray(0, 3).equals(Buffer.from([255, 216, 255]))
      : mime === "image/png"
        ? header
            .subarray(0, 8)
            .equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]))
        : mime === "image/webp"
          ? header.subarray(0, 4).toString() === "RIFF" &&
            header.subarray(8, 12).toString() === "WEBP"
          : ["image/heic", "image/heif"].includes(mime)
            ? ftyp &&
              ["heic", "heix", "hevc", "hevx", "mif1", "msf1"].includes(brand)
            : mime.startsWith("video/")
              ? ftyp &&
                ![
                  "heic",
                  "heix",
                  "hevc",
                  "hevx",
                  "mif1",
                  "msf1",
                  "avif",
                ].includes(brand)
              : mime === "application/pdf"
                ? header.subarray(0, 5).toString() === "%PDF-"
                : mime === "application/octet-stream";
  if (!validMime)
    throw new APIError(422, "Media bytes do not match declared type");
  if (!image) return undefined;
  try {
    const preview = await sharp(Buffer.concat(chunks), {
      limitInputPixels: 40_000_000,
    })
      .rotate()
      .resize({
        width: 640,
        height: 640,
        fit: "inside",
        withoutEnlargement: true,
      })
      .jpeg({ quality: 65 })
      .toBuffer();
    const meta = await sharp(preview).metadata();
    const label = Buffer.from(
      `<svg width="${meta.width}" height="${meta.height}"><rect x="0" y="${Math.max(0, (meta.height ?? 0) - 45)}" width="100%" height="45" fill="black" opacity=".5"/><text x="15" y="${Math.max(25, (meta.height ?? 0) - 16)}" fill="white" font-size="20">SLATE PREVIEW</text></svg>`,
    );
    const safe = await sharp(preview)
      .composite([{ input: label }])
      .jpeg()
      .toBuffer();
    const previewKey = key.replace("originals/", "previews/") + ".jpg";
    await s3.send(
      new PutObjectCommand({
        Bucket: bucket,
        Key: previewKey,
        Body: safe,
        ContentType: "image/jpeg",
        CacheControl: "private, no-store",
      }),
    );
    return previewKey;
  } catch {
    return undefined;
  }
}
export async function remove(key: string) {
  await s3.send(new DeleteObjectCommand({ Bucket: bucket, Key: key }));
}
export async function abort(key: string, uploadId: string) {
  try {
    await s3.send(
      new AbortMultipartUploadCommand({
        Bucket: bucket,
        Key: key,
        UploadId: uploadId,
      }),
    );
  } catch (error: any) {
    if (error.name !== "NoSuchUpload") throw error;
  }
}

export async function staleUploads(before: Date) {
  const found: {key:string,uploadId:string}[] = [];
  let keyMarker: string | undefined;
  let uploadMarker: string | undefined;
  do {
    const r = await s3.send(new ListMultipartUploadsCommand({Bucket:bucket,Prefix:'originals/',KeyMarker:keyMarker,UploadIdMarker:uploadMarker}));
    for(const upload of r.Uploads ?? []) if(upload.Initiated && upload.Initiated < before && upload.Key && upload.UploadId) found.push({key:upload.Key,uploadId:upload.UploadId});
    keyMarker=r.IsTruncated?r.NextKeyMarker:undefined;
    uploadMarker=r.IsTruncated?r.NextUploadIdMarker:undefined;
  } while(keyMarker);
  return found;
}
