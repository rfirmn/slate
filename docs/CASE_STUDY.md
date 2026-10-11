# Slate — Reliable delivery from project to payment

Creative professionals need project records, invoices, reliable file transfer, and secure client delivery to agree even when a phone loses connectivity. A progress bar that restarts after interruption and a payment screen that trusts a browser redirect do not solve that problem.

Slate is a native UIKit workspace backed by one TypeScript API and PostgreSQL. The client portal receives a revocable high-entropy capability, shows safe previews and server-derived invoice state, and asks the backend for each download. Original media sits in private S3-compatible storage. A download URL exists only briefly after the backend confirms payment, expected verified media, and explicit delivery release.

The two most failure-prone paths have different owners. A Swift actor coordinates a durable Core Data transfer journal and file-backed background URLSession tasks, with two concurrent parts and storage ListParts reconciliation. A backend transaction engine owns integer IDR, immutable issued invoice lines, request idempotency, payment attempts, event deduplication, and release checks. Object storage and PostgreSQL cannot commit atomically; persisted sessions and repeat-safe reconciliation resolve interrupted work.

The image gallery uses small supported image previews, while files retain their metadata and private original. Selected picker content is copied before a temporary provider URL expires and hashed in streaming blocks. A verified file is distinct from one whose bytes finished uploading. An offline project draft can be edited only when the client knows the original request could not have reached the server; ambiguous timeouts keep the payload and idempotency key fixed until reconciliation.

For local development, PostgreSQL and MinIO run in Compose. The official MinIO community image is no longer distributed; this project builds a pinned source tag. Payments use a visibly labeled signed simulator for deterministic local work or a Midtrans Sandbox adapter when merchant credentials and an HTTPS webhook are supplied. Simulation never means a real settlement.

Verification includes API database/storage concurrency tests, client-portal authorization tests, and native transition/hash/persistence tests. The final live native transfer test exercises a 17 MiB object and a stale queue journal. Simulator evidence does not establish force-quit behavior on hardware. Physical-device life-cycle and Instruments profiling remain follow-up validation rather than claimed results; see `docs/TESTING.md` for current status.
