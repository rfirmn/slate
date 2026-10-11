import "dotenv/config";
import { Hono } from "hono";
import { cors } from "hono/cors";
import { bodyLimit } from "hono/body-limit";
import { seal, unseal } from "./secrets.js";
import { z, ZodError } from "zod";
import { randomBytes, randomUUID } from "node:crypto";
import {
  db,
  TX,
  fullProject,
  idempotent,
  transaction,
  project,
  audit,
  lock,
} from "./db.js";
import {
  APIError,
  hash,
  passwordHash,
  passwordMatches,
  transitions,
  eligible,
  mediaReady,
  money,
} from "./domain.js";
import * as storage from "./storage.js";
import {
  developmentPayments,
  checkout,
  applyEvent,
  applyInside,
  providerStatus,
  signature,
  Event,
} from "./payments.js";
const uuid = z.string().uuid();
const text = z.string().trim().min(1).max(500);
const email = z.email().toLowerCase();
const partSize = 8388608;
export const app = new Hono<{
  Variables: { userId: string; sessionId: string };
}>();
app.use(
  "*",
  bodyLimit({
    maxSize: 1048576,
    onError: (c) => c.json({ error: "Request body too large" }, 413),
  }),
);
app.use(
  "*",
  cors({
    origin: process.env.PORTAL_URL ?? "http://localhost:3001",
    allowHeaders: ["Content-Type", "Authorization", "Idempotency-Key"],
    allowMethods: ["GET", "POST", "PATCH", "OPTIONS"],
  }),
);
app.use("*", async (c, next) => {
  const start = Date.now(),
    requestId = randomUUID();
  c.header("X-Request-ID", requestId);
  c.header("Cache-Control", "private, no-store");
  await next();
  console.log(
    JSON.stringify({
      requestId,
      method: c.req.method,
      path: c.req.path.replace(/\/portal\/[^/]+/, "/portal/[capability]"),
      status: c.res.status,
      durationMs: Date.now() - start,
    }),
  );
});
app.notFound(c=>c.json({error:"Route not found"},404));
app.onError((error, c) => {
  if (error instanceof APIError)
    return c.json({ error: error.message }, error.status as any);
  if (error instanceof ZodError || error instanceof SyntaxError)
    return c.json({ error: "Invalid request payload" }, 400);
  if ((error as any).code === "P2002")
    return c.json({ error: "Record already exists" }, 409);
  console.error(
    JSON.stringify({ error: "request_failed", type: error.constructor.name }),
  );
  return c.json(
    { error: "Request failed; retry safely using the same idempotency key" },
    500,
  );
});
app.get("/health", async (c) => {
  await db.$queryRaw`SELECT 1`;
  return c.json({ ok: true });
});
const credentials = z.object({ email, password: z.string().min(12).max(128) });
const userJSON = (u: any) => ({
  id: u.id,
  email: u.email,
  displayName: u.displayName,
});
async function session(u: any) {
  const token = randomBytes(32).toString("base64url");
  await db.session.create({
    data: {
      userId: u.id,
      tokenHash: hash(token),
      expiresAt: new Date(Date.now() + 30 * 86400000),
    },
  });
  return { token, user: userJSON(u) };
}
app.post("/auth/register", async (c) => {
  const body = credentials
    .extend({ displayName: text })
    .parse(await c.req.json());
  const u = await db.user.create({
    data: {
      email: body.email,
      displayName: body.displayName,
      passwordHash: passwordHash(body.password),
    },
  });
  return c.json(await session(u));
});
app.post("/auth/login", async (c) => {
  const body = credentials.parse(await c.req.json());
  const u = await db.user.findUnique({ where: { email: body.email } });
  if (!u || !passwordMatches(body.password, u.passwordHash))
    throw new APIError(401, "Invalid credentials");
  return c.json(await session(u));
});
app.use("*", async (c, next) => {
  if (
    c.req.path.startsWith("/portal/") ||
    c.req.path.startsWith("/webhooks/") ||
    c.req.path.startsWith("/dev/") ||
    c.req.path === "/health"
  )
    return next();
  const bearer = c.req.header("Authorization");
  if (!bearer?.startsWith("Bearer "))
    throw new APIError(401, "Authentication required");
  const s = await db.session.findUnique({
    where: { tokenHash: hash(bearer.slice(7)) },
  });
  if (!s || s.revokedAt || s.expiresAt < new Date())
    throw new APIError(401, "Session expired or revoked");
  c.set("userId", s.userId);
  c.set("sessionId", s.id);
  await next();
});
app.get("/auth/me", async (c) =>
  c.json(
    userJSON(
      await db.user.findUniqueOrThrow({ where: { id: c.get("userId") } }),
    ),
  ),
);
app.post("/auth/logout", async (c) => {
  await db.session.update({
    where: { id: c.get("sessionId") },
    data: { revokedAt: new Date() },
  });
  return c.json({ ok: true });
});
async function mediaJSON(m: any) {
  return {
    id: m.id,
    filename: m.filename,
    mimeType: m.mimeType,
    sizeBytes: Number(m.sizeBytes),
    status: m.status,
    contentHash: m.contentHash,
    verifiedAt: m.verifiedAt?.toISOString(),
    previewURL: m.previewKey
      ? await storage.signDownload(m.previewKey)
      : undefined,
  };
}
export const invoiceJSON = (i: any) =>
  i
    ? {
        id: i.id,
        invoiceNumber: i.invoiceNumber,
        status: i.status,
        totalMinor: i.totalMinor,
        currency: i.currency,
        dueAt: i.dueAt?.toISOString(),
        paidAt: i.paidAt?.toISOString(),
        items: i.items.map((x: any) => ({
          id: x.id,
          description: x.description,
          quantity: x.quantity,
          unitPriceMinor: x.unitPriceMinor,
          lineTotalMinor: x.lineTotalMinor,
        })),
        payments: i.payments.map((x: any) => ({
          id: x.id,
          status: x.status,
          provider: x.provider,
          createdAt: x.createdAt.toISOString(),
          amountMinor: x.amountMinor,
        })),
      }
    : null;
export async function projectJSON(p: any) {
  return {
    id: p.id,
    title: p.title,
    description: p.description,
    status: p.status,
    currency: p.currency,
    version: p.version,
    createdAt: p.createdAt.toISOString(),
    client: {
      id: p.client.id,
      name: p.client.name,
      email: p.client.email,
      phone: p.client.phone ?? undefined,
    },
    deliverables: p.deliverables.map((d: any) => ({
      id: d.id,
      title: d.title,
      type: d.type,
      expectedQuantity: d.expectedQuantity,
    })),
    invoice: invoiceJSON(p.invoice),
    media: await Promise.all(p.media.map(mediaJSON)),
    deliveryStatus:
      p.deliveryStatus === "RELEASED"
        ? "RELEASED"
        : p.deliveryStatus === "REVOKED"
          ? "REVOKED"
          : eligible(p)
            ? "ELIGIBLE"
            : "LOCKED",
    activity: p.activity.map((a: any) => ({
      id: a.id,
      action: a.action,
      createdAt: a.createdAt.toISOString(),
    })),
  };
}
async function updatedProject(tx: TX, id: string) {
  return projectJSON(
    await tx.project.findUniqueOrThrow({ where: { id }, include: fullProject }),
  );
}
const mutate = async (c: any, body: unknown, work: (tx: TX) => Promise<any>) =>
  c.json(
    await idempotent(
      "owner:" + c.get("userId"),
      c.req.header("Idempotency-Key"),
      c.req.method + c.req.path,
      body,
      work,
    ),
  );
app.get("/clients", async (c) =>
  c.json(
    (await db.client.findMany({ where: { ownerId: c.get("userId") } })).map(
      (x) => ({
        id: x.id,
        name: x.name,
        email: x.email,
        phone: x.phone ?? undefined,
      }),
    ),
  ),
);
app.post("/clients", async (c) => {
  const body = z
    .object({ name: text, email, phone: z.string().max(50).optional() })
    .parse(await c.req.json());
  return mutate(c, body, async (tx) => {
    const x = await tx.client.create({
      data: { ...body, ownerId: c.get("userId") },
    });
    return {
      id: x.id,
      name: x.name,
      email: x.email,
      phone: x.phone ?? undefined,
    };
  });
});
app.get("/projects", async (c) =>
  c.json(
    await Promise.all(
      (
        await db.project.findMany({
          where: { ownerId: c.get("userId") },
          include: fullProject,
          orderBy: { createdAt: "desc" },
        })
      ).map(projectJSON),
    ),
  ),
);
app.get("/projects/:id", async (c) =>
  c.json(
    await transaction(async (tx) =>
      projectJSON(
        await project(tx, uuid.parse(c.req.param("id")), c.get("userId")),
      ),
    ),
  ),
);
app.post("/projects", async (c) => {
  const body = z
    .object({
      title: text,
      description: z.string().max(5000),
      clientId: uuid,
      deliverables: z
        .array(
          z.object({
            title: text,
            type: z.enum([
              "PHOTO",
              "VIDEO",
              "FILE",
              "IMAGE",
              "DOCUMENT",
              "photo",
              "video",
              "image",
              "file",
              "document",
            ]),
            expectedQuantity: z.number().int().min(1).max(10000),
          }),
        )
        .min(1)
        .max(50),
    })
    .parse(await c.req.json());
  return mutate(c, body, async (tx) => {
    const client = await tx.client.findUnique({ where: { id: body.clientId } });
    if (client?.ownerId !== c.get("userId"))
      throw new APIError(404, "Client not found");
    const p = await tx.project.create({
      data: {
        title: body.title,
        description: body.description,
        clientId: body.clientId,
        ownerId: c.get("userId"),
        deliverables: { create: body.deliverables },
      },
    });
    await audit(tx, p.id, "project.created");
    return updatedProject(tx, p.id);
  });
});
app.patch("/projects/:id", async (c) => {
  const id = uuid.parse(c.req.param("id")),
    body = z
      .object({ status: z.string(), version: z.number().int().nonnegative() })
      .parse(await c.req.json());
  return mutate(c, body, async (tx) => {
    const p = await project(tx, id, c.get("userId"));
    if (p.version !== body.version)
      throw new APIError(409, "Project version conflict");
    if (!transitions[p.status]?.includes(body.status))
      throw new APIError(409, "Invalid project transition");
    if (body.status === "READY_FOR_DELIVERY" && !mediaReady(p))
      throw new APIError(409, "Deliverables are incomplete");
    if (
      body.status === "DELIVERED" &&
      (!eligible(p) || p.deliveryStatus !== "RELEASED")
    )
      throw new APIError(409, "Delivery not authorized");
    await tx.project.update({
      where: { id },
      data: {
        status: body.status,
        version: { increment: 1 },
        ...(body.status === "CANCELLED" ? { deliveryStatus: "REVOKED" } : {}),
      },
    });
    await audit(tx, id, "project." + body.status.toLowerCase());
    return updatedProject(tx, id);
  });
});
app.post("/projects/:id/invoices", async (c) => {
  const id = uuid.parse(c.req.param("id")),
    body = z
      .object({
        items: z
          .array(
            z.object({
              description: text,
              quantity: z.number().int().min(1).max(10000),
              unitPriceMinor: z.number().int().min(1).max(2147483647),
            }),
          )
          .min(1)
          .max(100),
        dueAt: z.iso.datetime().optional(),
      })
      .parse(await c.req.json());
  return mutate(c, body, async (tx) => {
    const p = await project(tx, id, c.get("userId"));
    if (p.invoice || p.status === "CANCELLED" || p.status === "COMPLETED")
      throw new APIError(409, "Project cannot create an invoice");
    const total = money(body.items);
    const i = await tx.invoice.create({
      data: {
        projectId: id,
        invoiceNumber:
          "SL-" + randomUUID().replaceAll("-", "").slice(0, 12).toUpperCase(),
        totalMinor: total,
        dueAt: body.dueAt ? new Date(body.dueAt) : null,
        items: {
          create: body.items.map((x) => ({
            ...x,
            lineTotalMinor: x.quantity * x.unitPriceMinor,
          })),
        },
      },
      include: { items: true, payments: true },
    });
    await audit(tx, id, "invoice.created");
    return invoiceJSON(i);
  });
});
async function ownerInvoice(tx: TX, id: string, owner: string) {
  const i = await tx.invoice.findUnique({ where: { id } });
  if (!i) throw new APIError(404, "Invoice not found");
  const p = await project(tx, i.projectId, owner);
  return p.invoice!;
}
for (const action of ["issue", "void"] as const)
  app.post("/invoices/:id/" + action, async (c) => {
    const id = uuid.parse(c.req.param("id")),
      body = await c.req.json();
    return mutate(c, body, async (tx) => {
      const i = await ownerInvoice(tx, id, c.get("userId"));
      if (
        (action === "issue" && i.status !== "DRAFT") ||
        (action === "void" && !["DRAFT", "ISSUED"].includes(i.status))
      )
        throw new APIError(409, "Invalid invoice transition");
      const next = await tx.invoice.update({
        where: { id },
        data: { status: action === "issue" ? "ISSUED" : "VOID" },
        include: { items: true, payments: true },
      });
      if (action === "void")
        await tx.project.update({
          where: { id: i.projectId },
          data: { deliveryStatus: "REVOKED" },
        });
      await audit(tx, i.projectId, "invoice." + action);
      return invoiceJSON(next);
    });
  });
app.post("/invoices/:id/reconcile", async (c) => {
  const id = uuid.parse(c.req.param("id")),
    body = await c.req.json();
  return mutate(c, body, async (tx) => {
    const i = await ownerInvoice(tx, id, c.get("userId"));
    for (const attempt of i.payments.filter((p) => p.provider === "midtrans")) {
      const e = await providerStatus(attempt.providerOrderId);
      if (e) await applyInside(tx, e, i.projectId, "midtrans");
    }
    await audit(tx, i.projectId, "payment.reconciled");
    return invoiceJSON(
      await tx.invoice.findUniqueOrThrow({
        where: { id },
        include: { items: true, payments: true },
      }),
    );
  });
});
app.post("/projects/:id/share", async (c) => {
  const id = uuid.parse(c.req.param("id")),
    body = await c.req.json();
  return mutate(c, body, async (tx) => {
    await project(tx, id, c.get("userId"));
    const token = randomBytes(32).toString("base64url");
    await tx.share.create({
      data: {
        projectId: id,
        tokenHash: hash(token),
        expiresAt: new Date(Date.now() + 30 * 86400000),
      },
    });
    await audit(tx, id, "share.created");
    return {
      token,
      url: `${process.env.PORTAL_URL ?? "http://localhost:3001"}/p/${token}`,
    };
  });
});
for (const action of ["release", "revoke"] as const)
  app.post("/projects/:id/delivery/" + action, async (c) => {
    const id = uuid.parse(c.req.param("id")),
      body = await c.req.json();
    return mutate(c, body, async (tx) => {
      const p = await project(tx, id, c.get("userId"));
      if (action === "release" && !eligible(p))
        throw new APIError(
          403,
          "Payment and verified deliverable quantities are required",
        );
      const status = action === "release" ? "RELEASED" : "REVOKED";
      await tx.project.update({
        where: { id },
        data: { deliveryStatus: status, version: { increment: 1 } },
      });
      await audit(tx, id, "delivery." + action);
      return { status };
    });
  });
async function transferOwner(tx: TX, id: string, owner: string) {
  await lock(tx, "transfer:" + id);
  const t = await tx.transfer.findUnique({
    where: { id },
    include: { media: true },
  });
  if (!t) throw new APIError(404, "Transfer not found");
  await project(tx, t.media.projectId, owner);
  return t;
}
function transferJSON(t: any) {
  return {
    id: t.id,
    mediaAssetId: t.mediaAssetId,
    status: t.status,
    totalBytes: Number(t.totalBytes),
    partSize: t.partSize,
    parts: t.parts,
    expiresAt: t.expiresAt.toISOString(),
  };
}
app.post("/transfers", async (c) => {
  const body = z
    .object({
      projectId: uuid,
      filename: z
        .string()
        .min(1)
        .max(255)
        .refine((s) => !/[\r\n\x00]/.test(s)),
      mimeType: z.enum([
        "image/jpeg",
        "image/png",
        "image/webp",
        "image/heic",
        "image/heif",
        "video/mp4",
        "video/quicktime",
        "application/pdf",
        "application/octet-stream",
      ]),
      sizeBytes: z
        .number()
        .int()
        .min(1)
        .max(partSize * 10000),
      contentHash: z
        .string()
        .regex(/^[0-9a-fA-F]{64}$/)
        .transform((s) => s.toLowerCase()),
    })
    .parse(await c.req.json());
  return mutate(c, body, async (tx) => {
    const p = await project(tx, body.projectId, c.get("userId"));
    if (["CANCELLED", "COMPLETED"].includes(p.status))
      throw new APIError(409, "Project no longer accepts media");
    const objectKey = "originals/" + p.id + "/" + randomUUID();
    const uploadId = await storage.startUpload(objectKey, body.mimeType);
    const m = await tx.mediaAsset.create({
      data: {
        ...body,
        sizeBytes: BigInt(body.sizeBytes),
        objectKey,
        transfer: {
          create: {
            uploadId,
            status: "UPLOADING",
            totalBytes: BigInt(body.sizeBytes),
            expiresAt: new Date(Date.now() + 2 * 86400000),
          },
        },
      },
      include: { transfer: true },
    });
    await audit(tx, p.id, "transfer.created");
    return transferJSON(m.transfer);
  });
});
app.get("/transfers/:id", async (c) =>
  c.json(
    await transaction(async (tx) => {
      const t = await transferOwner(
        tx,
        uuid.parse(c.req.param("id")),
        c.get("userId"),
      );
      if (t.status === "UPLOADING" && t.uploadId) {
        if (await storage.exists(t.media.objectKey)) {
          await tx.transfer.update({
            where: { id: t.id },
            data: { status: "VERIFYING" },
          });
          t.status = "VERIFYING";
        } else {
          const uploaded = await storage.parts(t.media.objectKey, t.uploadId);
          await tx.transfer.update({
            where: { id: t.id },
            data: { parts: uploaded },
          });
          t.parts = uploaded;
        }
      }
      return transferJSON(t);
    }),
  ),
);
app.post("/transfers/:id/parts/:number/sign", async (c) => {
  const id = uuid.parse(c.req.param("id")),
    number = z.coerce
      .number()
      .int()
      .min(1)
      .max(10000)
      .parse(c.req.param("number")),
    body = await c.req.json();
  return mutate(c, body, async (tx) => {
    const t = await transferOwner(tx, id, c.get("userId"));
    if (t.status !== "UPLOADING" || t.expiresAt < new Date() || !t.uploadId)
      throw new APIError(409, "Transfer unavailable");
    if (number > Math.ceil(Number(t.totalBytes) / t.partSize))
      throw new APIError(400, "Part number exceeds transfer size");
    return {
      url: await storage.signPart(t.media.objectKey, t.uploadId, number),
    };
  });
});
app.post("/transfers/:id/complete", async (c) => {
  const id = uuid.parse(c.req.param("id")),
    body = await c.req.json();
  const response = await idempotent(
    "owner:" + c.get("userId"),
    c.req.header("Idempotency-Key"),
    c.req.method + c.req.path,
    body,
    async (tx) => {
      const t = await transferOwner(tx, id, c.get("userId"));
      if (t.status === "COMPLETED")
        return { mediaAsset: await mediaJSON(t.media) };
      if (!["UPLOADING", "VERIFYING"].includes(t.status) || !t.uploadId)
        throw new APIError(409, "Transfer cannot complete");
      if (!(await storage.exists(t.media.objectKey))) {
        const uploaded = await storage.parts(t.media.objectKey, t.uploadId);
        const count = Math.ceil(Number(t.totalBytes) / t.partSize);
        if (
          uploaded.length !== count ||
          uploaded.some(
            (p, index) =>
              p.partNumber !== index + 1 ||
              p.sizeBytes !==
                (index === count - 1
                  ? Number(t.totalBytes) - index * t.partSize
                  : t.partSize),
          )
        )
          throw new APIError(409, "Upload parts incomplete or incorrect size");
        await storage.finish(t.media.objectKey, t.uploadId, uploaded);
        await tx.transfer.update({
          where: { id },
          data: { parts: uploaded, status: "VERIFYING" },
        });
      }
      try {
        const previewKey = await storage.verify(
          t.media.objectKey,
          t.media.contentHash,
          Number(t.totalBytes),
          t.media.mimeType,
        );
        const m = await tx.mediaAsset.update({
          where: { id: t.mediaAssetId },
          data: { status: "VERIFIED", verifiedAt: new Date(), previewKey },
        });
        await tx.transfer.update({
          where: { id },
          data: { status: "COMPLETED" },
        });
        await audit(tx, t.media.projectId, "media.verified");
        return { mediaAsset: await mediaJSON(m) };
      } catch (error) {
        if (!(error instanceof APIError && error.status === 422)) throw error;
        await tx.mediaAsset.update({
          where: { id: t.mediaAssetId },
          data: { status: "INVALID" },
        });
        await tx.transfer.update({
          where: { id },
          data: { status: "INVALID" },
        });
        await audit(tx, t.media.projectId, "media.integrity_failed");
        return { error: error.message };
      }
    },
  );
  if (response.error) return c.json(response, 422);
  return c.json(response);
});
app.post("/transfers/:id/cancel", async (c) => {
  const id = uuid.parse(c.req.param("id")),
    body = await c.req.json();
  return mutate(c, body, async (tx) => {
    const t = await transferOwner(tx, id, c.get("userId"));
    if (t.status === "COMPLETED")
      throw new APIError(409, "Completed transfer cannot be cancelled");
    if (t.uploadId) await storage.abort(t.media.objectKey, t.uploadId);
    await storage.remove(t.media.objectKey);
    await tx.transfer.update({ where: { id }, data: { status: "CANCELLED" } });
    await tx.mediaAsset.update({
      where: { id: t.mediaAssetId },
      data: { status: "INVALID" },
    });
    await audit(tx, t.media.projectId, "transfer.cancelled");
    return { ok: true };
  });
});
async function share(tx: TX, token: string) {
  if (!/^[A-Za-z0-9_-]{43}$/.test(token))
    throw new APIError(404, "Share not found");
  const s = await tx.share.findUnique({ where: { tokenHash: hash(token) } });
  if (!s || s.revokedAt || s.expiresAt < new Date())
    throw new APIError(404, "Share expired or revoked");
  return project(tx, s.projectId);
}
app.get("/portal/:token", async (c) =>
  c.json(
    await transaction(async (tx) => {
      const p = await share(tx, c.req.param("token"));
      const value = await projectJSON(p);
      return {
        project: value,
        deliveryStatus: value.deliveryStatus,
        developmentPayments,
      };
    }),
  ),
);
app.post("/portal/:token/checkout", async (c) => {
  const token=c.req.param("token"), body=await c.req.json();
  const key=uuid.parse(c.req.header("Idempotency-Key"));
  const scope="share:"+hash(token);
  // Commit the provider order intent before network I/O without borrowing a second pool connection.
  await transaction(async tx=>{
    await lock(tx,`idem:${scope}:${key}`);
    if(await tx.idempotency.findUnique({where:{scope_key:{scope,key}}})) return;
    const p=await share(tx,token);
    if(!p.invoice||p.invoice.status!=="ISSUED"||p.status==="CANCELLED") throw new APIError(409,"Invoice is not payable");
    const pending=await tx.paymentAttempt.findFirst({where:{invoiceId:p.invoice.id,status:"PENDING"}});
    if(!pending) { const id=randomUUID(); await tx.paymentAttempt.create({data:{id,invoiceId:p.invoice.id,provider:developmentPayments?"development":"midtrans",providerOrderId:id,amountMinor:p.invoice.totalMinor}}); }
  });
  return c.json(await idempotent(scope,key,c.req.method+"/portal/checkout",body,async tx=>{
    const p=await share(tx,token);
    if(!p.invoice||p.invoice.status!=="ISSUED"||p.status==="CANCELLED") throw new APIError(409,"Invoice is not payable");
    const attempt=await tx.paymentAttempt.findFirst({where:{invoiceId:p.invoice.id,status:"PENDING"},orderBy:{createdAt:"desc"}});
    if(!attempt) throw new APIError(409,"Payment attempt is no longer pending; refresh invoice");
    let redirectURL=attempt.redirectURL?unseal(attempt.redirectURL):null;
    if(!redirectURL) {redirectURL=await checkout(attempt.providerOrderId,attempt.amountMinor,token);await tx.paymentAttempt.update({where:{id:attempt.id},data:{redirectURL:seal(redirectURL)}});}
    await audit(tx,p.id,"payment.checkout_created");
    return {redirectURL,attemptId:attempt.id};
  }));
});
app.get("/portal/:token/media/:id/download", async (c) =>
  c.json(
    await transaction(async (tx) => {
      const p = await share(tx, c.req.param("token"));
      if (p.deliveryStatus !== "RELEASED" || !eligible(p))
        throw new APIError(403, "Final delivery is unavailable");
      const m = p.media.find(
        (m) =>
          m.id === uuid.parse(c.req.param("id")) && m.status === "VERIFIED",
      );
      if (!m) throw new APIError(404, "Media not found");
      await audit(tx, p.id, "delivery.download_authorized");
      return { url: await storage.signDownload(m.objectKey, m.filename) };
    }),
  ),
);
const eventSchema = z.object({
  order_id: z.string().uuid(),
  status_code: z.string().regex(/^\d{3}$/),
  gross_amount: z.string(),
  transaction_status: z.string(),
  fraud_status: z.string().optional(),
  signature_key: z.string().length(128),
  transaction_id: z.string().optional(),
});
app.post("/webhooks/midtrans", async (c) => {
  const e = eventSchema.parse(await c.req.json());
  return c.json(
    await applyEvent(e, process.env.MIDTRANS_SERVER_KEY ?? "", "midtrans"),
  );
});
app.post("/dev/payments/:attemptId/settle", async (c) => {
  if (!developmentPayments) throw new APIError(404, "Route unavailable");
  const secret = process.env.DEV_PAYMENT_SECRET!;
  const { safeEqual } = await import("./domain.js");
  if (!safeEqual(c.req.header("X-Dev-Secret") ?? "", secret))
    throw new APIError(401, "Development server authorization required");
  const attempt = await db.paymentAttempt.findUnique({
    where: { id: uuid.parse(c.req.param("attemptId")) },
  });
  if (!attempt || attempt.provider !== "development")
    throw new APIError(404, "Development payment not found");
  const e: Event = {
    order_id: attempt.providerOrderId,
    status_code: "200",
    gross_amount: `${attempt.amountMinor}.00`,
    transaction_status: "settlement",
    transaction_id: "dev-" + attempt.id,
    signature_key: "",
  };
  e.signature_key = signature(e, secret);
  return c.json(await applyEvent(e, secret, "development"));
});
