import assert from "node:assert/strict";
import test, { type TestContext } from "node:test";
import { GET as portal } from "../app/api/portal/[token]/route";
import { POST as checkout } from "../app/api/portal/[token]/checkout/route";
import { POST as simulate } from "../app/api/portal/[token]/simulate/route";

const token = "a".repeat(43);
const attemptId = "12345678-1234-1234-1234-123456789abc";
const context = () => ({ params: Promise.resolve({ token }) });
const responseData = { developmentPayments: true, project: { invoice: { payments: [{ id: attemptId, provider: "development" }] } } };

function environment(t: TestContext, mode: string) {
  const original = { NODE_ENV: process.env.NODE_ENV, DEVELOPMENT_PAYMENTS: process.env.DEVELOPMENT_PAYMENTS, DEV_PAYMENT_SECRET: process.env.DEV_PAYMENT_SECRET };
  Object.assign(process.env, { NODE_ENV: mode, DEVELOPMENT_PAYMENTS: "true", DEV_PAYMENT_SECRET: "route-test-secret" });
  t.after(() => {
    for (const [key, value] of Object.entries(original)) {
      if (value === undefined) delete process.env[key]; else process.env[key] = value;
    }
  });
}

test("production portal response suppresses API simulator flag and secret", async (t) => {
  environment(t, "production");
  t.mock.method(globalThis, "fetch", async () => Response.json(responseData));
  const result = await portal(new Request("http://localhost:3001/api/portal/" + token), context());
  const body = await result.json();
  assert.equal(body.developmentPayments, false);
  assert.equal(JSON.stringify(body).includes("route-test-secret"), false);
});

test("production simulator handler fails before contacting the backend", async (t) => {
  environment(t, "production");
  const fetchMock = t.mock.method(globalThis, "fetch", async () => { throw new Error("Must not contact backend"); });
  const result = await simulate(new Request(`http://localhost:3001/api/portal/${token}/simulate`, { method: "POST" }), context());
  assert.equal(result.status, 404);
  assert.equal(fetchMock.mock.callCount(), 0);
});

test("cross-origin checkout cannot initiate a provider side effect", async (t) => {
  const fetchMock = t.mock.method(globalThis, "fetch", async () => { throw new Error("Must not contact backend"); });
  const result = await checkout(new Request(`http://localhost:3001/api/portal/${token}/checkout`, { method: "POST", headers: { Origin: "https://untrusted.example" } }), context());
  assert.equal(result.status, 403);
  assert.equal(fetchMock.mock.callCount(), 0);
});

test("local simulation attaches secret server-side only after checking the capability", async (t) => {
  environment(t, "development");
  const calls: { path: string; headers: Headers }[] = [];
  t.mock.method(globalThis, "fetch", async (input: string | URL | Request, init?: RequestInit) => {
    calls.push({ path: new URL(String(input)).pathname, headers: new Headers(init?.headers) });
    return Response.json(calls.length === 1 ? responseData : { ok: true });
  });
  const result = await simulate(new Request(`http://localhost:3001/api/portal/${token}/simulate`, {
    method: "POST", headers: { Origin: "http://localhost:3001", "Content-Type": "application/json" }, body: JSON.stringify({ attemptId }),
  }), context());
  assert.equal(result.status, 200);
  assert.deepEqual(await result.json(), { ok: true });
  assert.equal(calls[0].path, `/portal/${token}`);
  assert.equal(calls[0].headers.get("X-Dev-Secret"), null);
  assert.equal(calls[1].path, `/dev/payments/${attemptId}/settle`);
  assert.equal(calls[1].headers.get("X-Dev-Secret"), "route-test-secret");
});

test("local simulator refuses another project's attempt without exposing the secret", async (t) => {
  environment(t, "development");
  const fetchMock = t.mock.method(globalThis, "fetch", async () => Response.json({ ...responseData, project: { invoice: { payments: [] } } }));
  const result = await simulate(new Request(`http://localhost:3001/api/portal/${token}/simulate`, {
    method: "POST", headers: { Origin: "http://localhost:3001", "Content-Type": "application/json" }, body: JSON.stringify({ attemptId }),
  }), context());
  assert.equal(result.status, 403);
  assert.equal(fetchMock.mock.callCount(), 1);
});
