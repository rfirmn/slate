# Verification record

Results last verified on 11 October 2026. Simulator and local Docker checks below passed; physical-device and merchant-backed checks need separate environments.

## Passed

- `xcodebuild ... build`, Simulator, Xcode 26.0.1, ad hoc signed: **passed** (`/tmp/slate-final-build2.log`). The only Xcode message was App Intents metadata skipped because Slate does not use App Intents.
- XCTest on a signed iPhone 17 Pro Simulator: **12 passed, 0 failed, 0 skipped**, including the live 17 MiB multipart integration test and a recovery test for a server-assembled object awaiting verification. The integration fixture sends a real first 8 MiB part, restores a stale local journal, confirms that the part is not retransmitted, completes remaining bytes via background URLSession, verifies matching server SHA-256 and file size, exercises offline draft edit/discard, and reconciles a completed upload against a late cancellation. See `/tmp/slate-final-tests-live.log`.
- Authenticated XCUITest on the same Simulator: **1 passed, 0 failed**. It signs in, creates a project, confirms it refreshes in the project list, opens its details, and checks the Photos and Files import options. See `/tmp/slate-final-ui-live-rerun.log`.
- API TypeScript build: **passed**. API unit tests: **6 passed**.
- API PostgreSQL/MinIO integration suite: **8 passed**, covering idempotency conflicts/races, account isolation/revocation, real multipart storage and recovery, invalid digest rejection, private previews/originals, payment/webhook concurrency, invoice void/late payment, and checkout replay. Latest run used the source-built MinIO Compose image, not an in-memory S3 fake.
- Portal: **11 tests passed**, TypeScript check and Next.js production build passed. Production simulation was rejected before backend access. Browser checks verified capability checkout settles once, duplicate settlement creates no extra attempt, unpaid originals are denied, released downloads work, and revoked future access is denied. Mobile layout was checked at 390 px without horizontal overflow.
- `npm run maintenance` ran successfully against local PostgreSQL and MinIO.

## Not measured

- No physical-device lifecycle or force-quit measurement was performed. No Instruments CPU/memory/battery or sustained throughput measurements were performed. Simulator timings are not representative of a production device/network.
- No merchant-backed Midtrans Sandbox checkout was performed; this requires merchant keys and a public HTTPS notification URL. The local simulator uses signed development events but is not represented as a payment provider transaction.

Run all suites with the commands in README. For authenticated native UI tests, set `SLATE_UI_INTEGRATION=1`; for the live S3/background recovery, set `SLATE_INTEGRATION=1` and `SLATE_API_URL=http://localhost:3000`. Pass these as Xcode build settings or environment variables to the scheme's test process. Build Simulator XCTest targets with `CODE_SIGN_IDENTITY=-` so Keychain and background URLSession have an application identity. Keep test credentials and storage local.
