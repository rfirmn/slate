# Reproducible demonstration

1. Run infrastructure, migrations, seed, API, portal, and the Simulator as described in README. Sign in with the seeded account. A freshly seeded database has an unpaid Spring Campaign invoice; in a reused database, that demo may already have been paid, so use a new project for a repeatable run.
2. Create a project for North Studio, add a PHOTO deliverable with quantity 1, confirm it, and begin work. Create and issue an integer IDR invoice.
3. Import a photo through the system picker (Simulator: add a photo through `simctl addmedia` or drag it into Simulator). For a large multipart demonstration, use a video larger than 16 MiB or a large PDF through Files.
4. Open Transfers. Pause a transfer, close/reopen Slate, and resume. Completed parts reconcile from storage. Stop MinIO temporarily to inject failures, restart it, and retry or restore. Byte transmission and verification have distinct UI states.
5. Share the portal and open its link in the browser. Before payment, image derivatives may be previewed but the original download endpoint returns a denial. Originals are never exposed as previews.
6. With the local development adapter enabled, open checkout and use the visibly labeled local simulator. This is a signed deterministic test event, not a merchant payment. For a merchant-backed demonstration configure Midtrans Sandbox instead.
7. Refresh the native project. Payment is now confirmed by the backend. Release final delivery only after required media have become VERIFIED. The portal now receives short-lived signed original download URLs.
8. Revoke access and verify that new download requests are rejected. A previously issued URL remains valid for its short expiry; revocation does not pretend to recall an already downloaded file.
9. Show the integration tests for duplicate keys/events, concurrent verification/payment, checksum mismatch, owner isolation, and denied downloads. Repeat an operation with the same key; change its payload and demonstrate conflict.
10. Show the native unit tests and opt-in 17 MiB real background multipart test. Distinguish Simulator results from physical-device lifecycle behavior.

Use `npm run maintenance` in `services/api` after simulating a backend crash or abandoning an upload. It is safe to run repeatedly. Do not expose development payment controls or local credentials outside a development environment.
