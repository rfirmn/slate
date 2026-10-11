import {
  createHash,
  randomBytes,
  scryptSync,
  timingSafeEqual,
} from "node:crypto";
export class APIError extends Error {
  constructor(
    public status: number,
    message: string,
  ) {
    super(message);
  }
}
export const hash = (value: string) =>
  createHash("sha256").update(value).digest("hex");
export function passwordHash(password: string) {
  const salt = randomBytes(16).toString("hex");
  return `${salt}:${scryptSync(password, salt, 64).toString("hex")}`;
}
export function passwordMatches(password: string, stored: string) {
  const [salt, key] = stored.split(":");
  if (!salt || !key) return false;
  const actual = scryptSync(password, salt, 64);
  const expected = Buffer.from(key, "hex");
  return expected.length === actual.length && timingSafeEqual(actual, expected);
}
export function safeEqual(a: string, b: string) {
  const x = Buffer.from(a),
    y = Buffer.from(b);
  return x.length === y.length && timingSafeEqual(x, y);
}
export function stable(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(stable).join(",")}]`;
  if (value && typeof value === "object")
    return `{${Object.entries(value)
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([k, v]) => JSON.stringify(k) + ":" + stable(v))
      .join(",")}}`;
  return JSON.stringify(value);
}
export const transitions: Record<string, string[]> = {
  DRAFT: ["CONFIRMED", "CANCELLED"],
  CONFIRMED: ["IN_PROGRESS", "CANCELLED"],
  IN_PROGRESS: ["READY_FOR_DELIVERY", "CANCELLED"],
  READY_FOR_DELIVERY: ["DELIVERED", "CANCELLED"],
  DELIVERED: ["COMPLETED"],
  COMPLETED: [],
  CANCELLED: [],
};
export function mediaKind(mime: string) {
  return mime.startsWith("image/")
    ? "PHOTO"
    : mime.startsWith("video/")
      ? "VIDEO"
      : "FILE";
}
export function normalizeKind(type: string) {
  const value = type.toUpperCase();
  return ["PHOTO", "IMAGE", "PHOTOGRAPH", "PHOTOGRAPHS", "PHOTOS"].includes(
    value,
  )
    ? "PHOTO"
    : ["VIDEO", "VIDEOS"].includes(value)
      ? "VIDEO"
      : "FILE";
}
export function eligible(project: any): boolean {
  return (
    project.status !== "CANCELLED" &&
    project.invoice?.status === "PAID" &&
    project.invoice.payments.some(
      (p: any) =>
        p.status === "SUCCEEDED" &&
        p.amountMinor === project.invoice.totalMinor,
    ) &&
    mediaReady(project)
  );
}
export function mediaReady(project: any): boolean {
  const required: Record<string, number> = {};
  for (const d of project.deliverables) {
    const kind = normalizeKind(d.type);
    required[kind] = (required[kind] ?? 0) + d.expectedQuantity;
  }
  return (
    project.deliverables.length > 0 &&
    Object.entries(required).every(
      ([kind, quantity]) =>
        project.media.filter(
          (m: any) => m.status === "VERIFIED" && mediaKind(m.mimeType) === kind,
        ).length >= quantity,
    )
  );
}
export function money(items: { quantity: number; unitPriceMinor: number }[]) {
  const total = items.reduce(
    (sum, i) => sum + i.quantity * i.unitPriceMinor,
    0,
  );
  if (!Number.isSafeInteger(total) || total < 1 || total > 2147483647)
    throw new APIError(
      400,
      "Invoice total is outside supported integer IDR range",
    );
  return total;
}
