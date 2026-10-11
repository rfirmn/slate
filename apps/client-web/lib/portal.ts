export type Invoice = {
  id: string; invoiceNumber: string; status: "DRAFT" | "ISSUED" | "PAID" | "VOID";
  totalMinor: number; currency: string; dueAt?: string; paidAt?: string;
  items: { id: string; description: string; quantity: number; unitPriceMinor: number; lineTotalMinor: number }[];
  payments: { id: string; status: string; provider: string; createdAt: string; amountMinor: number }[];
};
export type Media = { id: string; filename: string; mimeType: string; sizeBytes: number; status: string; previewURL?: string };
export type PortalData = {
  project: { id: string; title: string; description: string; status: string;
    client: { name: string }; deliverables: { id: string; title: string; expectedQuantity: number; type: string }[];
    invoice?: Invoice | null; media: Media[]; deliveryStatus: string };
  deliveryStatus: string; developmentPayments: boolean;
};

export function money(amount: number, currency = "IDR") {
  if (!Number.isSafeInteger(amount) || amount < 0) return "Amount unavailable";
  return new Intl.NumberFormat("id-ID", { style: "currency", currency, maximumFractionDigits: 0 }).format(amount);
}

export function deliveryAvailable(data: PortalData) {
  return data.project.invoice?.status === "PAID" && data.deliveryStatus === "RELEASED";
}

export function developmentEnabled(environment: Record<string, string | undefined>) {
  return environment.NODE_ENV !== "production" && environment.DEVELOPMENT_PAYMENTS === "true" && !!environment.DEV_PAYMENT_SECRET;
}

export function paymentBelongsToPortal(data: PortalData, attemptId: string) {
  return data.developmentPayments && data.project.invoice?.payments.some((payment) => payment.id === attemptId && payment.provider === "development") === true;
}

export function safeURL(value: string) {
  try {
    const url = new URL(value);
    return (url.protocol === "https:" || url.protocol === "http:") && !url.username && !url.password ? url.href : null;
  } catch { return null; }
}

export function sameOrigin(request: Request) {
  const origin = request.headers.get("origin");
  if (!origin) return false;
  try {
    const expected = new URL(request.url);
    const host = request.headers.get("x-forwarded-host") ?? request.headers.get("host");
    const protocol = request.headers.get("x-forwarded-proto")?.split(",")[0].trim();
    if (host) expected.host = host;
    if (protocol) expected.protocol = `${protocol.replace(/:$/, "")}:`;
    return new URL(origin).origin === expected.origin;
  } catch { return false; }
}

export function newIdempotencyKey() {
  const bytes = globalThis.crypto.getRandomValues(new Uint8Array(16));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const hex = Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join("");
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}
