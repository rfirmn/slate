import { db } from "../src/db.js";
import { passwordHash } from "../src/domain.js";
const user = await db.user.upsert({
  where: { email: "demo@slate.local" },
  update: {},
  create: {
    email: "demo@slate.local",
    displayName: "Alex Morgan",
    passwordHash: passwordHash("SlateDemo2026!"),
  },
});
const existing = await db.client.findFirst({
  where: { ownerId: user.id, email: "hello@northstudio.example" },
});
if (!existing) {
  const client = await db.client.create({
    data: {
      ownerId: user.id,
      name: "North Studio",
      email: "hello@northstudio.example",
    },
  });
  await db.project.create({
    data: {
      ownerId: user.id,
      clientId: client.id,
      title: "Spring Campaign",
      description:
        "Campaign portraits and product photography for North Studio.",
      status: "IN_PROGRESS",
      deliverables: {
        create: [
          { title: "Campaign photographs", type: "PHOTO", expectedQuantity: 1 },
        ],
      },
      invoice: {
        create: {
          invoiceNumber: "SL-DEMO-001",
          status: "ISSUED",
          totalMinor: 5000000,
          items: {
            create: {
              description: "Campaign photography and editing",
              quantity: 1,
              unitPriceMinor: 5000000,
              lineTotalMinor: 5000000,
            },
          },
        },
      },
      activity: { create: { action: "project.demo_created" } },
    },
  });
}
console.log("Seeded demo@slate.local / SlateDemo2026!");
await db.$disconnect();
