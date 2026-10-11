import "dotenv/config";
import test, { after, before } from "node:test";
import assert from "node:assert/strict";
import { randomUUID, createHash } from "node:crypto";
import sharp from "sharp";
import { app } from "../src/app.js";
import { db } from "../src/db.js";
import { s3, bucket, remove, abort } from "../src/storage.js";
import { HeadObjectCommand } from "@aws-sdk/client-s3";
import { applyEvent, signature, Event } from "../src/payments.js";
const ids: string[] = [];
async function request(
  method: string,
  path: string,
  token?: string,
  body?: unknown,
  key = randomUUID(),
) {
  const res = await app.request(path, {
    method,
    headers: {
      ...(token ? { Authorization: "Bearer " + token } : {}),
      ...(body !== undefined
        ? { "Content-Type": "application/json", "Idempotency-Key": key }
        : {}),
    },
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });
  assert.equal(res.headers.get("Cache-Control"), "private, no-store");
  const data: any = await res.json();
  return { status: res.status, data };
}
async function owner() {
  const email = randomUUID() + "@integration.example";
  const r = await request("POST", "/auth/register", undefined, {
    email,
    password: "IntegrationTest2026!",
    displayName: "Test Owner",
  });
  assert.equal(r.status, 200);
  ids.push(r.data.user.id);
  return r.data.token as string;
}
async function fixture(token: string, type = "FILE", quantity = 1) {
  const c = await request("POST", "/clients", token, {
    name: "Test Client",
    email: "test@example.com",
  });
  const p = await request("POST", "/projects", token, {
    title: "Integration Project",
    description: "Test",
    clientId: c.data.id,
    deliverables: [{ title: "Final", type, expectedQuantity: quantity }],
  });
  assert.equal(p.status, 200);
  const i = await request("POST", `/projects/${p.data.id}/invoices`, token, {
    items: [
      { description: "Media project", quantity: 1, unitPriceMinor: 100000 },
    ],
  });
  assert.equal(i.status, 200);
  await request("POST", `/invoices/${i.data.id}/issue`, token, {});
  const sh = await request("POST", `/projects/${p.data.id}/share`, token, {});
  return { project: p.data, invoice: i.data, share: sh.data.token as string };
}
async function transfer(
  token: string,
  projectId: string,
  bytes: Buffer,
  mime = "application/octet-stream",
  bad = false,
) {
  const contentHash = bad
    ? "0".repeat(64)
    : createHash("sha256").update(bytes).digest("hex");
  const t = await request("POST", "/transfers", token, {
    projectId,
    filename: "media.bin",
    mimeType: mime,
    sizeBytes: bytes.length,
    contentHash,
  });
  assert.equal(t.status, 200);
  return t.data;
}
async function upload(token: string, t: any, bytes: Buffer) {
  for (
    let number = 1;
    number <= Math.ceil(bytes.length / t.partSize);
    number++
  ) {
    const s = await request(
      "POST",
      `/transfers/${t.id}/parts/${number}/sign`,
      token,
      {},
    );
    assert.equal(s.status, 200);
    const response = await fetch(s.data.url, {
      method: "PUT",
      body: new Uint8Array(
        bytes.subarray((number - 1) * t.partSize, number * t.partSize),
      ),
    });
    assert.equal(response.status, 200);
  }
}
async function pay(f: any) {
  const checkout = await request(
    "POST",
    `/portal/${f.share}/checkout`,
    undefined,
    {},
  );
  assert.equal(checkout.status, 200);
  const e: Event = {
    order_id: checkout.data.attemptId,
    status_code: "200",
    gross_amount: "100000.00",
    transaction_status: "settlement",
    transaction_id: "test-" + checkout.data.attemptId,
    signature_key: "",
  };
  e.signature_key = signature(e, process.env.DEV_PAYMENT_SECRET!);
  return e;
}
before(async () => {
  await db.$connect();
  assert.equal(
    process.env.PAYMENT_PROVIDER,
    "development",
    "Integration suite requires explicit development provider",
  );
});
after(async () => {
  for (const id of ids) {
    const projects = await db.project.findMany({
      where: { ownerId: id },
      select: { id: true },
    });
    const pids = projects.map((x) => x.id);
    const assets = await db.mediaAsset.findMany({where:{projectId:{in:pids}},include:{transfer:true}});
    for(const media of assets) { if(media.transfer?.uploadId) await abort(media.objectKey,media.transfer.uploadId); await remove(media.objectKey); if(media.previewKey) await remove(media.previewKey); }
    const shares = await db.share.findMany({where:{projectId:{in:pids}}});
    await db.idempotency.deleteMany({where:{scope:{in:shares.map(s=>'share:'+s.tokenHash)}}});
    await db.paymentEvent.deleteMany({
      where: { attempt: { invoice: { projectId: { in: pids } } } },
    });
    await db.paymentAttempt.deleteMany({
      where: { invoice: { projectId: { in: pids } } },
    });
    await db.invoiceItem.deleteMany({
      where: { invoice: { projectId: { in: pids } } },
    });
    await db.invoice.deleteMany({ where: { projectId: { in: pids } } });
    await db.transfer.deleteMany({
      where: { media: { projectId: { in: pids } } },
    });
    await db.mediaAsset.deleteMany({ where: { projectId: { in: pids } } });
    await db.auditEvent.deleteMany({ where: { projectId: { in: pids } } });
    await db.share.deleteMany({ where: { projectId: { in: pids } } });
    await db.deliverable.deleteMany({ where: { projectId: { in: pids } } });
    await db.project.deleteMany({ where: { ownerId: id } });
    await db.client.deleteMany({ where: { ownerId: id } });
    await db.user.delete({ where: { id } });
    await db.idempotency.deleteMany({ where: { scope: "owner:" + id } });
  }
  await db.$disconnect();
});
test("concurrent same idempotency key commits once and mismatch rejects", async () => {
  const token = await owner(),
    key = randomUUID(),
    body = { name: "Only One", email: "single@example.com" };
  const replies = await Promise.all(
    Array.from({ length: 8 }, () =>
      request("POST", "/clients", token, body, key),
    ),
  );
  assert.ok(replies.every((r) => r.status === 200));
  assert.equal(new Set(replies.map((r) => r.data.id)).size, 1);
  assert.equal((await request("GET", "/clients", token)).data.length, 1);
  assert.equal(
    (
      await request(
        "POST",
        "/clients",
        token,
        { ...body, name: "Different" },
        key,
      )
    ).status,
    409,
  );
});
test("owner isolation, session revocation, invalid transitions", async () => {
  const a = await owner(),
    b = await owner(),
    f = await fixture(a);
  assert.equal(
    (await request("GET", "/projects/" + f.project.id, b)).status,
    404,
  );
  assert.equal(
    (await request("POST", `/projects/${f.project.id}/delivery/release`, b, {}))
      .status,
    404,
  );
  assert.equal(
    (
      await request("PATCH", `/projects/${f.project.id}`, a, {
        status: "COMPLETED",
        version: 0,
      })
    ).status,
    409,
  );
  assert.equal((await request("POST", "/auth/logout", a, {})).status, 200);
  assert.equal((await request("GET", "/auth/me", a)).status, 401);
});
test("multipart resume trusts storage parts, unpaid denied, duplicate payment+completion concurrent, release and revoke", async () => {
  const token = await owner(),
    f = await fixture(token),
    bytes = Buffer.alloc(8 * 1024 * 1024 + 123, 42),
    t = await transfer(token, f.project.id, bytes);
  let s = await request("POST", `/transfers/${t.id}/parts/1/sign`, token, {});
  assert.equal(
    (
      await fetch(s.data.url, {
        method: "PUT",
        body: new Uint8Array(bytes.subarray(0, t.partSize)),
      })
    ).status,
    200,
  );
  const restored = await request("GET", "/transfers/" + t.id, token);
  assert.equal(restored.data.parts.length, 1);
  assert.equal(
    (await request("POST", `/transfers/${t.id}/complete`, token, {})).status,
    409,
  );
  s = await request("POST", `/transfers/${t.id}/parts/2/sign`, token, {});
  assert.equal(
    (
      await fetch(s.data.url, {
        method: "PUT",
        body: new Uint8Array(bytes.subarray(t.partSize)),
      })
    ).status,
    200,
  );
  assert.equal(
    (
      await request(
        "POST",
        `/projects/${f.project.id}/delivery/release`,
        token,
        {},
      )
    ).status,
    403,
  );
  const e = await pay(f);
  const key = randomUUID();
  const replies = await Promise.all([
    request("POST", `/transfers/${t.id}/complete`, token, {}, key),
    ...Array.from({ length: 6 }, () =>
      applyEvent(e, process.env.DEV_PAYMENT_SECRET!, "development"),
    ),
  ]);
  assert.equal((replies[0] as any).status, 200);
  const complete = await request(
    "POST",
    `/transfers/${t.id}/complete`,
    token,
    {},
    key,
  );
  assert.equal(complete.status, 200);
  const p = await request("GET", "/projects/" + f.project.id, token);
  assert.equal(p.data.invoice.status, "PAID");
  assert.equal(p.data.deliveryStatus, "ELIGIBLE");
  assert.equal(
    await db.paymentEvent.count({ where: { attemptId: e.order_id } }),
    1,
  );
  assert.equal(
    p.data.activity.filter((x: any) => x.action === "payment.verified").length,
    1,
  );
  const download = `/portal/${f.share}/media/${t.mediaAssetId}/download`;
  assert.equal((await request("GET", download)).status, 403);
  assert.equal(
    (
      await request(
        "POST",
        `/projects/${f.project.id}/delivery/release`,
        token,
        {},
      )
    ).status,
    200,
  );
  const authorized = await request("GET", download);
  assert.equal(authorized.status, 200);
  const response = await fetch(authorized.data.url);
  assert.equal(response.status, 200);
  assert.deepEqual(Buffer.from(await response.arrayBuffer()), bytes);
  assert.equal(
    (
      await request(
        "POST",
        `/projects/${f.project.id}/delivery/revoke`,
        token,
        {},
      )
    ).status,
    200,
  );
  assert.equal((await request("GET", download)).status, 403);
});
test("tampered amount, invalid hash and false payment cannot unlock", async () => {
  const token = await owner(),
    f = await fixture(token),
    bytes = Buffer.from("corrupt bytes"),
    t = await transfer(
      token,
      f.project.id,
      bytes,
      "application/octet-stream",
      true,
    );
  await upload(token, t, bytes);
  const key = randomUUID();
  assert.equal(
    (await request("POST", `/transfers/${t.id}/complete`, token, {}, key))
      .status,
    422,
  );
  assert.equal(
    (await request("POST", `/transfers/${t.id}/complete`, token, {}, key))
      .status,
    422,
  );
  assert.equal(
    (await db.mediaAsset.findUniqueOrThrow({ where: { id: t.mediaAssetId } }))
      .status,
    "INVALID",
  );
  const e = await pay(f),
    wrong = { ...e, gross_amount: "1.00" };
  wrong.signature_key = signature(wrong, process.env.DEV_PAYMENT_SECRET!);
  await assert.rejects(() =>
    applyEvent(wrong, process.env.DEV_PAYMENT_SECRET!, "development"),
  );
  assert.equal(
    (await request("POST", `/dev/payments/${e.order_id}/settle`, undefined, {}))
      .status,
    401,
  );
  await applyEvent(e, process.env.DEV_PAYMENT_SECRET!, "development");
  assert.equal(
    (
      await request(
        "POST",
        `/projects/${f.project.id}/delivery/release`,
        token,
        {},
      )
    ).status,
    403,
  );
});
test("completion recovers ambiguous committed object, safe thumbnail only and private bucket", async () => {
  const token = await owner(),
    f = await fixture(token, "PHOTO"),
    bytes = await sharp({
      create: { width: 1200, height: 800, channels: 3, background: "#8899aa" },
    })
      .jpeg()
      .toBuffer(),
    t = await transfer(token, f.project.id, bytes, "image/jpeg");
  await upload(token, t, bytes);
  const m = await db.mediaAsset.findUniqueOrThrow({
    where: { id: t.mediaAssetId },
  });
  const { parts, finish } = await import("../src/storage.js");
  const tr = await db.transfer.findUniqueOrThrow({ where: { id: t.id } });
  await finish(
    m.objectKey,
    tr.uploadId!,
    await parts(m.objectKey, tr.uploadId!),
  );
  const restored = await request("GET", "/transfers/" + t.id, token);
  assert.equal(restored.data.status, "VERIFYING");
  assert.equal(
    (await request("POST", `/transfers/${t.id}/complete`, token, {})).status,
    200,
  );
  const portal = await request("GET", "/portal/" + f.share);
  const previewURL = portal.data.project.media[0].previewURL;
  assert.ok(previewURL.includes("previews"));
  assert.ok(!JSON.stringify(portal.data).includes("objectKey"));
  const preview = await fetch(previewURL);
  assert.equal(preview.status, 200);
  const meta = await sharp(Buffer.from(await preview.arrayBuffer())).metadata();
  assert.ok(meta.width! <= 640);
  assert.equal(
    (await fetch(`http://localhost:9000/${bucket}/${m.objectKey}`)).status,
    403,
  );
  assert.equal(
    (await request("GET", `/portal/${f.share}/media/${m.id}/download`)).status,
    403,
  );
  await s3.send(new HeadObjectCommand({ Bucket: bucket, Key: m.objectKey }));
});
test("refund revokes access and stale pending event cannot restore it", async () => {
  const token = await owner(),
    f = await fixture(token),
    bytes = Buffer.from("deliverable"),
    t = await transfer(token, f.project.id, bytes);
  await upload(token, t, bytes);
  await request("POST", `/transfers/${t.id}/complete`, token, {});
  const e = await pay(f);
  await applyEvent(e, process.env.DEV_PAYMENT_SECRET!, "development");
  await request(
    "POST",
    `/projects/${f.project.id}/delivery/release`,
    token,
    {},
  );
  const refund = { ...e, transaction_status: "refund" };
  refund.signature_key = signature(refund, process.env.DEV_PAYMENT_SECRET!);
  await applyEvent(refund, process.env.DEV_PAYMENT_SECRET!, "development");
  const pending = { ...e, transaction_status: "pending" };
  pending.signature_key = signature(pending, process.env.DEV_PAYMENT_SECRET!);
  await applyEvent(pending, process.env.DEV_PAYMENT_SECRET!, "development");
  assert.equal(
    (
      await request(
        "GET",
        `/portal/${f.share}/media/${t.mediaAssetId}/download`,
      )
    ).status,
    403,
  );
  assert.equal(
    (
      await request(
        "POST",
        `/projects/${f.project.id}/delivery/release`,
        token,
        {},
      )
    ).status,
    403,
  );
});

test('payment events concurrent and invoice void rejects late settlement', async () => {
  const token = await owner();
  const f = await fixture(token);
  const e = await pay(f);
  await Promise.all(Array.from({ length: 12 }, () => applyEvent(e, process.env.DEV_PAYMENT_SECRET!, 'development')));
  const p = await request('GET', '/projects/' + f.project.id, token);
  assert.equal(p.data.invoice.status, 'PAID');
  assert.equal(p.data.activity.filter((x: any) => x.action === 'payment.verified').length, 1);
  assert.equal(await db.paymentEvent.count({ where: { attemptId: e.order_id } }), 1);
  assert.equal((await request('POST', '/invoices/' + f.invoice.id + '/void', token, {})).status, 409);
  const invalid = { ...e, signature_key: '0'.repeat(128) };
  assert.equal((await request('POST', '/webhooks/midtrans', undefined, invalid)).status, 401);
  const other = await fixture(token);
  const late = await pay(other);
  assert.equal((await request('POST', '/invoices/' + other.invoice.id + '/void', token, {})).status, 200);
  await applyEvent(late, process.env.DEV_PAYMENT_SECRET!, 'development');
  const voided = await request('GET', '/projects/' + other.project.id, token);
  assert.equal(voided.data.invoice.status, 'VOID');
  assert.equal(voided.data.invoice.payments[0].status, 'SUCCEEDED');
  assert.equal((await request('POST', '/projects/' + other.project.id + '/delivery/release', token, {})).status, 403);
});


test("concurrent checkout retries persist one durable provider attempt", async()=>{
  const token=await owner(), f=await fixture(token), key=randomUUID();
  const replies=await Promise.all(Array.from({length:24},()=>request('POST',`/portal/${f.share}/checkout`,undefined,{},key)));
  assert.ok(replies.every(r=>r.status===200),JSON.stringify(replies));
  assert.equal(new Set(replies.map(r=>r.data.attemptId)).size,1);
  assert.equal(await db.paymentAttempt.count({where:{invoiceId:f.invoice.id}}),1);
  const different=await request('POST',`/portal/${f.share}/checkout`,undefined,{different:true},key);
  assert.equal(different.status,409);
});
