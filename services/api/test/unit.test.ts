import test from "node:test";
import assert from "node:assert/strict";
import {
  eligible,
  mediaReady,
  money,
  passwordHash,
  passwordMatches,
  stable,
  APIError,
} from "../src/domain.js";
import { signature, validateEvent } from "../src/payments.js";
import { seal, unseal } from "../src/secrets.js";
test("integer financial calculations reject overflow", () => {
  assert.equal(money([{ quantity: 3, unitPriceMinor: 25000 }]), 75000);
  assert.throws(
    () => money([{ quantity: 10000, unitPriceMinor: 2147483647 }]),
    APIError,
  );
});
test("scrypt hash and constant time verification", () => {
  const hashed = passwordHash("SlateDemo2026!");
  assert.ok(passwordMatches("SlateDemo2026!", hashed));
  assert.ok(!passwordMatches("wrong", hashed));
  assert.notEqual(hashed, passwordHash("SlateDemo2026!"));
});
test("canonical fingerprint independent of JSON key ordering", () =>
  assert.equal(stable({ b: 2, a: [1, 2] }), stable({ a: [1, 2], b: 2 })));
test("delivery sums quantities by media type and requires verified paid attempt", () => {
  const p: any = {
    status: "READY_FOR_DELIVERY",
    invoice: {
      status: "PAID",
      totalMinor: 10,
      payments: [{ status: "SUCCEEDED", amountMinor: 10 }],
    },
    deliverables: [
      { type: "PHOTO", expectedQuantity: 1 },
      { type: "PHOTO", expectedQuantity: 1 },
      { type: "VIDEO", expectedQuantity: 1 },
    ],
    media: [
      { mimeType: "image/jpeg", status: "VERIFIED" },
      { mimeType: "video/mp4", status: "VERIFIED" },
    ],
  };
  assert.ok(!eligible(p));
  p.media.push({ mimeType: "image/png", status: "VERIFIED" });
  assert.ok(eligible(p));
  p.invoice.payments[0].status = "REFUNDED";
  assert.ok(!eligible(p));
  assert.ok(mediaReady(p));
  p.status = "CANCELLED";
  assert.ok(!eligible(p));
});
test("provider signature binds order status code and integer amount", () => {
  const e: any = {
    order_id: "abc",
    status_code: "200",
    gross_amount: "5000.00",
    transaction_status: "settlement",
  };
  e.signature_key = signature(e, "secret");
  assert.doesNotThrow(() => validateEvent(e, "secret"));
  assert.throws(() =>
    validateEvent({ ...e, gross_amount: "5001.00" }, "secret"),
  );
  assert.throws(() => validateEvent(e, "wrong"));
});
test("encrypted idempotent responses do not store capability plaintext", () => {
  const value = JSON.stringify({ token: "high-entropy-capability" });
  const encoded = seal(value);
  assert.ok(!encoded.includes("high-entropy"));
  assert.equal(unseal(encoded), value);
  assert.throws(() => unseal(encoded.slice(0, -4) + "AAAA"));
});
