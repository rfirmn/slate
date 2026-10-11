import { createHash } from "node:crypto";
import { APIError, safeEqual, hash } from "./domain.js";
import { db, transaction, project, audit, TX } from "./db.js";
export const developmentPayments =
  process.env.NODE_ENV !== "production" &&
  process.env.PAYMENT_PROVIDER === "development" &&
  process.env.DEVELOPMENT_PAYMENTS === "true" &&
  !!process.env.DEV_PAYMENT_SECRET;
const serverKey = () => process.env.MIDTRANS_SERVER_KEY ?? "";
const basic = () =>
  `Basic ${Buffer.from(serverKey() + ":").toString("base64")}`;
export async function checkout(orderId: string, amount: number, token: string) {
  if (developmentPayments)
    return `${process.env.PORTAL_URL ?? "http://localhost:3001"}/p/${encodeURIComponent(token)}?attempt=${orderId}&simulator=1`;
  if (!serverKey())
    throw new APIError(503, "Midtrans Sandbox is not configured");
  const r = await fetch(
    "https://app.sandbox.midtrans.com/snap/v1/transactions",
    {
      method: "POST",
      headers: { Authorization: basic(), "Content-Type": "application/json" },
      body: JSON.stringify({
        transaction_details: { order_id: orderId, gross_amount: amount },
        callbacks: {
          finish: `${process.env.PORTAL_URL ?? "http://localhost:3001"}/p/${encodeURIComponent(token)}`,
        },
      }),
      signal: AbortSignal.timeout(15000),
    },
  );
  const json: any = await r.json();
  if (!r.ok || !json.redirect_url)
    throw new APIError(
      502,
      "Payment checkout unavailable; reconcile before retrying",
    );
  return json.redirect_url as string;
}
export type Event = {
  order_id: string;
  status_code: string;
  gross_amount: string;
  transaction_status: string;
  fraud_status?: string;
  signature_key: string;
  transaction_id?: string;
};
export function signature(e: Omit<Event, "signature_key">, key: string) {
  return createHash("sha512")
    .update(e.order_id + e.status_code + e.gross_amount + key)
    .digest("hex");
}
export function validateEvent(e: Event, key: string) {
  if (!key || !safeEqual(signature(e, key), e.signature_key))
    throw new APIError(401, "Invalid payment signature");
  if (
    !/^\d+(\.00)?$/.test(e.gross_amount) ||
    !Number.isSafeInteger(Number(e.gross_amount))
  )
    throw new APIError(400, "Invalid IDR payment amount");
}
export async function applyEvent(e: Event, key: string, provider: string) {
  validateEvent(e, key);
  const known = await db.paymentAttempt.findUnique({
    where: { providerOrderId: e.order_id },
    include: { invoice: true },
  });
  if (!known || known.provider !== provider)
    throw new APIError(404, "Payment attempt not found");
  return transaction(async (tx) =>
    applyInside(tx, e, known.invoice.projectId, provider),
  );
}
export async function applyInside(
  tx: TX,
  e: Event,
  projectId: string,
  provider: string,
) {
  const p = await project(tx, projectId);
  const attempt = await tx.paymentAttempt.findUnique({
    where: { providerOrderId: e.order_id },
  });
  if (
    !attempt ||
    attempt.provider !== provider ||
    Number(e.gross_amount) !== attempt.amountMinor ||
    attempt.amountMinor !== p.invoice?.totalMinor
  )
    throw new APIError(422, "Payment amount or provider mismatch");
  const eventKey = hash(
    provider +
      ":" +
      e.order_id +
      ":" +
      (e.transaction_id ?? "") +
      ":" +
      e.transaction_status +
      ":" +
      e.status_code +
      ":" +
      (e.fraud_status ?? ""),
  );
  if (await tx.paymentEvent.findUnique({ where: { eventKey } }))
    return { ok: true };
  const successful =
    e.status_code === "200" &&
    (e.transaction_status === "settlement" ||
      (e.transaction_status === "capture" && e.fraud_status === "accept"));
  const status = successful
    ? "SUCCEEDED"
    : ["deny", "cancel", "expire", "failure"].includes(e.transaction_status)
      ? "FAILED"
      : ["refund", "partial_refund", "chargeback"].includes(
            e.transaction_status,
          )
        ? "REFUNDED"
        : "PENDING";
  await tx.paymentEvent.create({
    data: { eventKey, attemptId: attempt.id, status },
  });
  if (status === "REFUNDED") {
    await tx.paymentAttempt.update({
      where: { id: attempt.id },
      data: { status },
    });
    await tx.project.update({
      where: { id: projectId },
      data: { deliveryStatus: "REVOKED" },
    });
    await audit(tx, projectId, "payment.refunded.delivery_revoked");
  } else if (attempt.status !== "SUCCEEDED" && attempt.status !== "REFUNDED") {
    if (successful && p.invoice?.status === "ISSUED") {
      await tx.paymentAttempt.update({
        where: { id: attempt.id },
        data: { status },
      });
      await tx.invoice.update({
        where: { id: attempt.invoiceId },
        data: { status: "PAID", paidAt: new Date() },
      });
      await audit(tx, projectId, "payment.verified");
    } else if (successful && p.invoice?.status === "PAID") {
      await tx.paymentAttempt.update({
        where: { id: attempt.id },
        data: { status },
      });
      await audit(
        tx,
        projectId,
        "payment.additional_settlement_review_required",
      );
    } else if (successful) {
      await tx.paymentAttempt.update({
        where: { id: attempt.id },
        data: { status: "SUCCEEDED" },
      });
      await audit(
        tx,
        projectId,
        "payment.settlement_rejected_for_void_invoice",
      );
    } else if (attempt.status === "PENDING" && status !== "PENDING") {
      await tx.paymentAttempt.update({
        where: { id: attempt.id },
        data: { status },
      });
      await audit(tx, projectId, "payment.failed");
    }
  }
  return { ok: true };
}
export async function providerStatus(
  order: string,
): Promise<Event | undefined> {
  if (developmentPayments) return undefined;
  const r = await fetch(
    `https://api.sandbox.midtrans.com/v2/${encodeURIComponent(order)}/status`,
    { headers: { Authorization: basic() }, signal: AbortSignal.timeout(15000) },
  );
  if (r.status === 404) return undefined;
  if (!r.ok) throw new APIError(502, "Provider reconciliation unavailable");
  const e: any = await r.json();
  if (e.order_id !== order)
    throw new APIError(502, "Provider returned different order");
  if (!e.signature_key) e.signature_key = signature(e, serverKey());
  validateEvent(e, serverKey());
  return e;
}
