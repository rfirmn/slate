# Slate API

Node LTS, Hono, Prisma/PostgreSQL and private S3-compatible storage. Copy `.env.example` to `.env` and keep local credentials out of commits. Commands run from this directory:

```sh
npm ci
npm run db:generate
npm run db:migrate
npm run db:seed
npm run dev
npm run build
npm test
npm run test:integration
npm run maintenance
```

Start infrastructure from the repository root with `docker compose -f infrastructure/docker-compose.yml up -d --build`. PostgreSQL is exposed at `127.0.0.1:55432` to avoid macOS PostgreSQL port conflicts. MinIO is exposed at port9000, console9001. Its pinned source build avoids unavailable official image registries; the first build downloads Go modules and can take several minutes. The API creates the private bucket and maintenance aborts abandoned multipart uploads. It can serve authentication/project/payment routes before storage is available; upload creation retries storage initialization on demand.

Seed login: `demo@slate.local` / `SlateDemo2026!`. This fixture starts with one PHOTO deliverable and an issued IDR5,000,000 invoice. Upload a verified image, use the explicit simulator or Midtrans Sandbox to pay, and explicitly release before clients can download originals.

Local deterministic payments require `PAYMENT_PROVIDER=development`, `DEVELOPMENT_PAYMENTS=true`, a non-production `NODE_ENV`, and `DEV_PAYMENT_SECRET`. The portal server must configure the same secret. To use real Sandbox checkout set `PAYMENT_PROVIDER=midtrans` and supply a Midtrans Sandbox server key; point its notification URL to the API `/webhooks/midtrans` through a reachable HTTPS development tunnel. No live payments are configured by this implementation.

The server uses SHA256 bearer/share hashes, salted scrypt passwords, expiring revocable sessions, project ownership checks, canonical request fingerprints, transactional advisory locks, encrypted idempotency responses, provider signatures/amount validation, storage-authoritative multipart parts, streaming SHA256 and explicit delivery authorization. See `docs/TRANSACTION_ENGINE.md` and `docs/DELIVERY_SECURITY.md` for boundaries and recovery details.

Integration tests require the explicit development provider and real PostgreSQL/MinIO, and use isolated owners rather than deleting the seed account. Run maintenance periodically in the existing deployment scheduler. Production must set its own long encryption key, session/storage/payment secrets, HTTPS URLs and private storage policy. Preserve the encryption key for response replay across restarts.

Known limits: no live Midtrans credentials are bundled; no video thumbnails; image previews are limited to20MiB and40million pixels. A lost provider checkout response retains its durable order for reconciliation but cannot recover a lost Snap redirect token automatically. Revoke prevents new URLs; issued URLs expire within60seconds. Large-file performance is not claimed without measurements.
