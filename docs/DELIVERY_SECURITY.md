# Delivery security

The creator API uses high entropy opaque bearer sessions. PostgreSQL stores SHA256 token hashes, expiry and revocation state. Passwords use a per-password random salt and Node scrypt. Logout revokes the server session immediately. Every project, invoice, client and transfer route verifies the authenticated owner's relation before returning or changing state.

Client portal links are 256-bit capabilities with 30-day expiry, stored as SHA256 hashes. They identify exactly one project and do not grant creator authority. The portal response is an explicit DTO: no storage object keys, upload IDs, password/session hashes, provider references or checkout secrets. Replayable share responses and capability-containing checkout URLs are encrypted at rest so idempotency does not undermine hashed capability storage.

## Preview boundary

MinIO's bucket is private and the API never installs an anonymous read policy. Originals use `originals/<project>/<random UUID>` keys. A preview is a separate JPEG object produced after successful SHA256/size verification, decoded with Sharp, reduced to at most 640 × 640, and visibly labeled `SLATE PREVIEW`. Only JPEG/PNG/WebP/HEIC/HEIF files up to 20 MiB and a 40-million-pixel decoder limit are considered for thumbnail generation. A decode failure leaves no preview; the original is never substituted. Video and document previews are omitted in this MVP. MIME magic bytes are checked against claimed media type before accepting verification.

The capability response exposes a 60-second signed URL to this separate thumbnail only. Thumbnails deliberately reveal a low-resolution visual preview to anyone holding the capability. They are not a DRM mechanism and recipients can retain what they have already viewed. Signed URLs and capabilities are omitted from structured logs.

## Final delivery gate

Every final download request rechecks authoritative state while holding the same PostgreSQL project lock as payment and media updates:

1. The share exists, is unexpired and is not revoked.
2. The invoice is `PAID` and has a verified `SUCCEEDED` attempt for its exact full integer IDR total.
3. The project is not cancelled.
4. Required deliverable quantities are summed by photo/video/file kind, and that many assets of each kind are `VERIFIED`.
5. The creator explicitly set delivery to `RELEASED`.
6. The requested verified asset belongs to this exact project.

A pending invoice, invalid checksum, wrong owner/project, insufficient quantity, missing release or revoked delivery returns an error. Uploading enough photos cannot fulfill a video requirement. Caller-supplied media status or payment flags are never trusted. The server records each authorized final download and issues an attachment URL that expires in 60 seconds.

Explicit revoke and verified refund stop future URL issuance. Already issued signed URLs remain valid for at most their remaining 60-second lifetime; already downloaded files cannot be recalled. Release after a refund fails unless a valid successful full payment remains. Production delivery should use HTTPS and deployment-specific private-network credentials; local HTTP exists solely for simulator development.

## Transfer verification and recovery

Storage ListParts, rather than client-reported ETags, defines confirmed parts. Parts must be consecutive and have exact expected sizes (8 MiB except the final part). Completion streams the stored original through SHA256 with bounded memory, compares the byte count and expected digest, then atomically marks the asset verified. Thumbnail generation has a separate bounded image buffer; large files never enter that path. A completed multipart object with uncommitted database status is discoverable by HeadObject and can be reverified by repeating complete. Integrity mismatch commits an invalid tombstone and cannot enter the delivery gate.

The maintenance command recovers verifiable finalized expired transfers, aborts abandoned multipart uploads, deletes expired/invalid/cancelled private objects, and reconciles payments. The same command lists and aborts incomplete storage uploads older than two days, including uploads created before a process lost its database transaction. This does not depend on MinIO supporting AWS bucket lifecycle multipart rules. Keep the original mismatch tombstone for audit; reupload using a new transfer. Cancelling a completed verified transfer is rejected.

## Limits requiring external verification

No real merchant Sandbox event is claimed without credentials and an exercised provider callback. Malware scanning, content DRM, video transcoding and instant revocation of already issued storage URLs are outside this MVP. Large-file throughput and physical-device networking require measured tests; no capacity benchmark is inferred from the implementation.
