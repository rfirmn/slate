import {
  createCipheriv,
  createDecipheriv,
  createHash,
  randomBytes,
} from "node:crypto";
const secret = process.env.IDEMPOTENCY_ENCRYPTION_KEY;
if (process.env.NODE_ENV === "production" && (!secret || secret.length < 32))
  throw new Error(
    "Production requires IDEMPOTENCY_ENCRYPTION_KEY (at least 32 characters)",
  );
const key = createHash("sha256")
  .update(secret ?? "slate-local-only-encryption-key-change-me")
  .digest();
export function seal(value: string) {
  const iv = randomBytes(12);
  const cipher = createCipheriv("aes-256-gcm", key, iv);
  const data = Buffer.concat([cipher.update(value, "utf8"), cipher.final()]);
  return [
    "v1",
    iv.toString("base64url"),
    cipher.getAuthTag().toString("base64url"),
    data.toString("base64url"),
  ].join(".");
}
export function unseal(value: string) {
  const [version, iv, tag, data] = value.split(".");
  if (version !== "v1") throw new Error("Invalid encrypted response");
  const decipher = createDecipheriv(
    "aes-256-gcm",
    key,
    Buffer.from(iv, "base64url"),
  );
  decipher.setAuthTag(Buffer.from(tag, "base64url"));
  return Buffer.concat([
    decipher.update(Buffer.from(data, "base64url")),
    decipher.final(),
  ]).toString("utf8");
}
