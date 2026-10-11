import assert from "node:assert/strict";
import test from "node:test";
import { developmentEnabled, deliveryAvailable, money, newIdempotencyKey, paymentBelongsToPortal, safeURL, sameOrigin, type PortalData } from "../lib/portal";

const fixture: PortalData = {
  project: { id: "project-a", title: "Campaign", description: "", status: "READY_FOR_DELIVERY", client: { name: "Studio" },
    deliverables: [], media: [], deliveryStatus: "RELEASED",
    invoice: { id: "invoice-a", invoiceNumber: "SL-1", status: "PAID", totalMinor: 5000000, currency: "IDR", items: [],
      payments: [{ id: "attempt-a", provider: "development", status: "SUCCEEDED", amountMinor: 5000000, createdAt: "2026-10-11" }] } },
  deliveryStatus: "RELEASED", developmentPayments: true,
};

test("UI only offers original downloads for paid and released delivery", () => {
  assert.equal(deliveryAvailable(fixture), true);
  assert.equal(deliveryAvailable({ ...fixture, deliveryStatus: "REVOKED" }), false);
  assert.equal(deliveryAvailable({ ...fixture, project: { ...fixture.project, invoice: { ...fixture.project.invoice!, status: "ISSUED" } } }), false);
});
test("local simulation is disabled in production even with development flags", () => {
  assert.equal(developmentEnabled({ NODE_ENV: "production", DEVELOPMENT_PAYMENTS: "true", DEV_PAYMENT_SECRET: "secret" }), false);
  assert.equal(developmentEnabled({ NODE_ENV: "development", DEVELOPMENT_PAYMENTS: "false", DEV_PAYMENT_SECRET: "secret" }), false);
  assert.equal(developmentEnabled({ NODE_ENV: "development", DEVELOPMENT_PAYMENTS: "true" }), false);
  assert.equal(developmentEnabled({ NODE_ENV: "development", DEVELOPMENT_PAYMENTS: "true", DEV_PAYMENT_SECRET: "secret" }), true);
});
test("simulation cannot settle an attempt from another capability or real provider", () => {
  assert.equal(paymentBelongsToPortal(fixture, "attempt-a"), true);
  assert.equal(paymentBelongsToPortal(fixture, "attempt-b"), false);
  assert.equal(paymentBelongsToPortal({ ...fixture, developmentPayments: false }, "attempt-a"), false);
  assert.equal(paymentBelongsToPortal({ ...fixture, project: { ...fixture.project, invoice: { ...fixture.project.invoice!, payments: [{ ...fixture.project.invoice!.payments[0], provider: "midtrans" }] } } }, "attempt-a"), false);
});
test("capability mutation requires the actual request origin", () => {
  assert.equal(sameOrigin(new Request("http://localhost:3001/api/portal/token/checkout", { headers: { Origin: "http://localhost:3001" } })), true);
  assert.equal(sameOrigin(new Request("http://localhost:3001/api/portal/token/checkout", { headers: { Origin: "https://evil.example" } })), false);
  assert.equal(sameOrigin(new Request("http://localhost:3001/api/portal/token/checkout")), false);
  assert.equal(sameOrigin(new Request("http://0.0.0.0:3001/api/portal/token/checkout", { headers: { Origin: "http://172.20.10.3:3001", Host: "172.20.10.3:3001" } })), true);
  assert.equal(sameOrigin(new Request("http://0.0.0.0:3001/api/portal/token/checkout", { headers: { Origin: "https://evil.example", Host: "172.20.10.3:3001" } })), false);
});
test("checkout idempotency key works without crypto.randomUUID", () => {
  assert.match(newIdempotencyKey(), /^[a-f\d]{8}-[a-f\d]{4}-4[a-f\d]{3}-[89ab][a-f\d]{3}-[a-f\d]{12}$/i);
});
test("navigation never accepts executable or credential-bearing URLs", () => {
  assert.equal(safeURL("javascript:alert(1)"), null);
  assert.equal(safeURL("data:text/html,hello"), null);
  assert.equal(safeURL("https://user:secret@example.com/file"), null);
  assert.equal(safeURL("https://storage.example.com/file?signature=a"), "https://storage.example.com/file?signature=a");
});
test("IDR integer rupiah formatting does not scale or accept fractional values", () => {
  assert.match(money(5000000), /5\.000\.000/);
  assert.equal(money(1.5), "Amount unavailable");
  assert.equal(money(Number.MAX_SAFE_INTEGER + 1), "Amount unavailable");
});
