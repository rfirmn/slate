import { db, transaction, project, audit, lock } from "./db.js";
import * as storage from "./storage.js";
import { providerStatus, applyEvent } from "./payments.js";
// Each operation uses the same locks as interactive routes; rerunning this command is safe.
for (const t of await db.transfer.findMany({
  where: {
    status: { in: ["UPLOADING", "VERIFYING"] },
    expiresAt: { lt: new Date() },
  },
  include: { media: true },
}))
  await transaction(async (tx) => {
    await lock(tx, "transfer:" + t.id);
    await project(tx, t.media.projectId);
    const current = await tx.transfer.findUniqueOrThrow({
      where: { id: t.id },
    });
    if (!["UPLOADING", "VERIFYING"].includes(current.status)) return;
    const object = await storage.exists(t.media.objectKey);
    if (object) {
      try {
        const previewKey = await storage.verify(
          t.media.objectKey,
          t.media.contentHash,
          Number(t.totalBytes),
          t.media.mimeType,
        );
        await tx.mediaAsset.update({
          where: { id: t.mediaAssetId },
          data: { status: "VERIFIED", verifiedAt: new Date(), previewKey },
        });
        await tx.transfer.update({
          where: { id: t.id },
          data: { status: "COMPLETED" },
        });
        await audit(tx, t.media.projectId, "transfer.recovered");
        return;
      } catch (error: any) {
        if (error.status !== 422) throw error;
      }
    }
    if (t.uploadId) await storage.abort(t.media.objectKey, t.uploadId);
    await storage.remove(t.media.objectKey);
    await tx.transfer.update({
      where: { id: t.id },
      data: { status: "EXPIRED" },
    });
    await tx.mediaAsset.update({
      where: { id: t.mediaAssetId },
      data: { status: "INVALID" },
    });
    await audit(tx, t.media.projectId, "transfer.expired");
  });
for (const p of await db.paymentAttempt.findMany({
  where: { provider: "midtrans", status: "PENDING" },
})) {
  try {
    const e = await providerStatus(p.providerOrderId);
    if (e)
      await applyEvent(e, process.env.MIDTRANS_SERVER_KEY ?? "", "midtrans");
  } catch {
    console.error(
      JSON.stringify({
        event: "payment.reconciliation_failed",
        attemptId: p.id,
      }),
    );
  }
}
for (const t of await db.transfer.findMany({
  where: { status: { in: ["INVALID", "EXPIRED", "CANCELLED"] } },
  include: { media: true },
})) {
  if (t.uploadId) await storage.abort(t.media.objectKey, t.uploadId);
  await storage.remove(t.media.objectKey);
  if (t.media.previewKey) await storage.remove(t.media.previewKey);
}
for(const upload of await storage.staleUploads(new Date(Date.now()-2*86400000))) { await storage.abort(upload.key,upload.uploadId); console.log(JSON.stringify({event:'storage.stale_multipart_aborted'})); }
await db.session.deleteMany({ where: { expiresAt: { lt: new Date() } } });
await db.$disconnect();
