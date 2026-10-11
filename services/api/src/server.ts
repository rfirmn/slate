import { serve } from "@hono/node-server";
import { app } from "./app.js";
import { initStorage } from "./storage.js";
import { db } from "./db.js";
await db.$connect();
const server = serve(
  { fetch: app.fetch, port: Number(process.env.PORT ?? 3000) },
  () =>
    console.log(
      JSON.stringify({
        event: "api.ready",
        port: Number(process.env.PORT ?? 3000),
      }),
    ),
);
void initStorage().catch(() =>
  console.error(
    JSON.stringify({
      event: "storage.unavailable",
      message: "Uploads will retry storage initialization on demand",
    }),
  ),
);
for (const signal of ["SIGTERM", "SIGINT"])
  process.on(signal, () =>
    server.close(() => void db.$disconnect().then(() => process.exit(0))),
  );
