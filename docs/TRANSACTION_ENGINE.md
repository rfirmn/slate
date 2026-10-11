# Transaction engine

Slate's authoritative transaction state lives in PostgreSQL, accessed through Prisma. Amounts are integer IDR rupiah. The API calculates line totals and invoice totals; quantities, prices, total bounds and matching line totals are validated by both the API and database constraints. No client action directly writes `PAID`.

## States and boundaries

Invoices move `DRAFT → ISSUED → PAID`, or `DRAFT/ISSUED → VOID`. A paid invoice cannot be voided. A payment attempt moves from `PENDING` to `SUCCEEDED`, `FAILED`, or `REFUNDED`; a refund revokes delivery. A late failed or pending event cannot downgrade a successful payment. A verified settlement arriving for a void invoice remains recorded as a successful attempt for investigation, but does not reopen the invoice or authorize delivery. Additional settlements are auditable and require manual review; the MVP has no automated refund issuance.

Each project mutation acquires a PostgreSQL transaction advisory lock for the project UUID. Invoice issue/void, payment application, media completion, release, revoke and download authorization therefore serialize against the same project. Project status changes also compare the submitted optimistic `version` and validate the state graph. PostgreSQL remains authoritative even when multiple API processes handle requests.

## Idempotency

Creator mutations and portal checkout require an `Idempotency-Key` UUID. A database advisory lock on `(scope, key)` serializes concurrent retries. The record contains a fingerprint of method, route and canonically sorted JSON input. Reusing a key with another payload returns 409. The operation result and its idempotency record commit together; a retry after an ambiguous response returns the saved result. Owners and hashed share capabilities have separate scopes. Records are retained, so cleanup does not accidentally permit replaying old financial commands.

Replayable response bodies are AES-256-GCM encrypted with `IDEMPOTENCY_ENCRYPTION_KEY`. This includes capability tokens and signed URLs. Keep the same configured key across process restarts and backup/restore. Production startup rejects a missing/short key; the local fallback is explicitly for development. Original share tokens are only hashed in `Share`, and checkout URLs containing capabilities are encrypted in payment records.

## Provider boundary

The adapter creates real Midtrans **Sandbox** Snap checkout transactions using the server key. Attempts are committed durably before the external request, with their UUID as the provider order ID. A returned redirect is encrypted and committed before completing the logical checkout response. A process crash therefore preserves an order reference for webhook processing and reconciliation. Duplicate checkout commands use the current pending attempt. An ambiguous provider timeout leaves a pending attempt, not a fabricated success; reconcile with Midtrans before retrying. If Midtrans created a checkout but its redirect response was lost, the existing order remains reconcilable, but this MVP cannot retrieve a lost Snap token; operational follow-up or provider cancellation is required before creating a replacement.

Midtrans notification signatures use the provider's SHA512 formula: order ID + status code + gross amount + server key. Comparisons are constant time. The stored attempt provider, order, IDR amount and invoice total must all match. Settlement/capture-with-accepted-fraud status and code 200 are the only success states. A provider event fingerprint is unique at the database level; project locking makes duplicate concurrent notifications harmless. Payment event insertion, attempt update, invoice update and audit event commit atomically.

Owner reconciliation queries the provider's authenticated status endpoint and applies the result through the same transaction handler. `npm run maintenance` reconciles pending Midtrans attempts and expired storage transfers. Schedule it in the deployment's existing scheduler; no additional service is required.

## Explicit local simulator

With `NODE_ENV != production`, `PAYMENT_PROVIDER=development`, `DEVELOPMENT_PAYMENTS=true` and `DEV_PAYMENT_SECRET` configured, checkout uses an explicit development page. The Next portal's server route authenticates the share-to-attempt relationship and invokes `/dev/payments/:attemptId/settle` with `X-Dev-Secret`. The API generates a signed development provider event and feeds the same verified transaction handler. The browser never receives the server secret or creator session. Production hides this route and reports `developmentPayments: false`. The simulator is for deterministic local engineering tests, and does not constitute a live Midtrans payment.

## Verification

`test/unit.test.ts` covers integer calculations, signatures, canonical fingerprints, encryption, scrypt passwords and summed deliverable quantities. `test/integration.test.ts` exercises a real PostgreSQL/MinIO pair: concurrent idempotency requests, payload conflicts, owner isolation, revocable sessions, duplicate events, concurrent payment/upload completion, refunds, mismatch rejection and private delivery. See the final test report for executed results; configured Midtrans merchant credentials are required to verify real Sandbox callbacks.
