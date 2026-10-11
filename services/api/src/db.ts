import "dotenv/config";
import { PrismaClient, Prisma } from "@prisma/client";
import { APIError, hash, stable } from "./domain.js";
import { seal, unseal } from "./secrets.js";
export const db = new PrismaClient();
export type TX = Prisma.TransactionClient;
export const fullProject = {
  client: true,
  deliverables: true,
  invoice: { include: { items: true, payments: true } },
  media: true,
  activity: { orderBy: { createdAt: "desc" as const }, take: 100 },
};
export async function lock(tx: TX, key: string) {
  await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtextextended(${key},0))`;
}
export async function transaction<T>(work: (tx: TX) => Promise<T>): Promise<T> {
  return db.$transaction(work, { maxWait: 20000, timeout: 120000 });
}
export async function idempotent(
  scope: string,
  key: string | undefined,
  path: string,
  input: unknown,
  work: (tx: TX) => Promise<any>,
) {
  if (
    !key ||
    !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(key)
  )
    throw new APIError(400, "Idempotency-Key must be a UUID");
  const fingerprint = hash(path + stable(input));
  return transaction(async (tx) => {
    await lock(tx, `idem:${scope}:${key}`);
    const previous = await tx.idempotency.findUnique({
      where: { scope_key: { scope, key } },
    });
    if (previous) {
      if (previous.fingerprint !== fingerprint)
        throw new APIError(
          409,
          "Idempotency key reused with different request",
        );
      return JSON.parse(unseal((previous.response as any).encrypted));
    }
    const response = JSON.parse(JSON.stringify(await work(tx)));
    await tx.idempotency.create({
      data: {
        scope,
        key,
        fingerprint,
        response: { encrypted: seal(JSON.stringify(response)) },
      },
    });
    return response;
  });
}
export async function project(tx: TX, id: string, owner?: string) {
  await lock(tx, `project:${id}`);
  const p = await tx.project.findUnique({
    where: { id },
    include: fullProject,
  });
  if (!p || (owner && p.ownerId !== owner))
    throw new APIError(404, "Project not found");
  return p;
}
export async function audit(tx: TX, projectId: string, action: string) {
  await tx.auditEvent.create({ data: { projectId, action } });
}
