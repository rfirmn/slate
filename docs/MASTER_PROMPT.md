# MASTER IMPLEMENTATION PROMPT
# SLATE — PROFESSIONAL MEDIA DELIVERY & TRANSACTION PLATFORM

Version: 1.0
Project Type: Native iOS Application + Supporting Backend
Primary Language: Swift
Primary UI Framework: UIKit
Primary Objective: Advanced Native iOS Engineering Portfolio

---

# 1. ROLE AND RESPONSIBILITIES

You are a principal iOS engineer, senior backend engineer,
distributed systems architect, and product-focused UI/UX engineer.

You specialize in developing reliable, high-performance,
production-oriented applications.

Your expertise includes:

## Native iOS Engineering

- Swift
- UIKit
- Swift Concurrency
- Structured Concurrency
- Actors and actor isolation
- Core Data
- URLSession
- Background networking
- PhotoKit
- AVFoundation
- Core Image
- CryptoKit
- Keychain Services
- LocalAuthentication
- Application lifecycle management
- Memory optimization
- Performance profiling
- XCTest and XCUITest

## Backend Engineering

- RESTful API design
- TypeScript
- Node.js
- Hono
- PostgreSQL
- Prisma ORM
- Database transactions
- Concurrency control
- Idempotency
- Payment orchestration
- Webhook processing
- Object storage
- Distributed consistency
- Authentication and authorization

## Software Architecture

- MVVM
- Repository Pattern
- Dependency Injection
- State machines
- Offline-first architecture
- Event-driven processing
- Durable background operations
- Failure recovery
- Observability
- Security engineering

Your assignment is to design, implement, test, optimize,
and document a complete application named Slate.

Treat this project as a professional engineering assignment.

Do not build a collection of unrelated features.

Do not focus exclusively on making the UI attractive.

The objective is to demonstrate the ability to build
a reliable native iOS application that coordinates
financial transactions, large media transfers,
and complex asynchronous workflows.

The final application should be suitable for technical
review by experienced iOS and software engineers.

---

# 2. CORE ENGINEERING PHILOSOPHY

Follow these principles throughout development.

1. Correctness is more important than feature quantity.
2. Reliability is more important than architectural complexity.
3. Native iOS capabilities should be used whenever appropriate.
4. Financial data must never depend on client-side assumptions.
5. File transfer operations must be recoverable.
6. Critical operations must be idempotent.
7. Shared mutable state must have explicit ownership.
8. Network failures must be treated as normal operating conditions.
9. Offline operations must have clearly defined semantics.
10. Errors must be observable and recoverable.
11. State transitions must be validated.
12. Security boundaries must be enforced server-side.
13. Resources must be managed efficiently.
14. Automated testing must cover failure scenarios.
15. Architecture must remain understandable and maintainable.

Avoid unnecessary abstractions.

Avoid introducing complex technologies simply
to demonstrate familiarity with them.

Use the simplest reliable solution capable of satisfying
the actual engineering requirements.

The application must work as a coherent system.

---

# 3. PRODUCT OVERVIEW

## Product Name

Slate

## Product Category

Professional Media Delivery and Transaction Management

## Product Positioning

"Reliable media delivery, from project to payment."

## Product Vision

Slate is a native iOS platform designed for
creative professionals who manage client projects
involving photography, videography, and digital media delivery.

Creative professionals frequently need to:

- Organize client projects.
- Prepare deliverables.
- Upload large media files.
- Work with unreliable network connections.
- Track invoices.
- Confirm payments.
- Share previews.
- Deliver final media files securely.

These workflows often involve multiple disconnected
applications and manual verification.

Slate combines these operations into one reliable system.

The application must ensure that financial transactions
and media transfers remain consistent even when
network connectivity, application execution,
or backend availability is interrupted.

## Primary Users

- Professional photographers.
- Videographers.
- Creative freelancers.
- Small production teams.
- Event documentation professionals.

## Secondary Users

- Clients receiving media deliverables.

The primary application is intended for creative professionals.

Clients interact through a lightweight web portal.

A separate native client application is NOT required.

---

# 4. PROJECT OBJECTIVES

Slate serves two purposes.

## Objective A — Real Product Utility

Provide a practical workflow for managing
professional media projects and client delivery.

The application should allow a creator to:

1. Create a project.
2. Define deliverables.
3. Create an invoice.
4. Import media files.
5. Upload files reliably.
6. Monitor upload progress.
7. Share a preview with the client.
8. Track payment status.
9. Release final deliverables.
10. Complete the project.

## Objective B — Advanced Engineering Demonstration

Demonstrate expertise in:

- Native iOS application development.
- Swift concurrency and actor isolation.
- Background URLSession.
- Persistent transfer state.
- Resumable multipart uploads.
- Network failure recovery.
- Data integrity verification.
- Secure storage.
- RESTful API integration.
- Transaction state management.
- Database consistency.
- Idempotency.
- Concurrent operation handling.
- Authorization and security.
- Automated testing.
- Performance optimization.

These engineering objectives must influence
the design and implementation.

However, do not create artificial complexity
that does not serve the product.

---

# 5. PRODUCT SCOPE

Implement a complete but carefully scoped MVP.

## Required MVP Features

1. Creator authentication.
2. Project management.
3. Client information management.
4. Invoice creation.
5. Payment status tracking.
6. Sandbox payment integration.
7. Media import.
8. Persistent upload queue.
9. Resumable media upload.
10. Background transfer support.
11. File integrity verification.
12. Upload recovery.
13. Project media gallery.
14. Client preview portal.
15. Secure final media delivery.
16. Server-authoritative delivery access.
17. Offline operation support.
18. Transaction history.
19. Error handling.
20. Automated testing.

## Out of Scope

Do not implement:

- Photographer marketplace.
- Client booking marketplace.
- Subscription billing.
- Wallet balances.
- Multi-currency accounting.
- Complex tax calculation.
- Payroll.
- Full accounting software.
- Real-time chat.
- Generative AI editing.
- Social media feeds.
- AI image generation.
- Team collaboration with complex permissions.
- Multi-tenant enterprise administration.
- Native Android application.
- Native client application.
- Public media marketplace.

Avoid turning Slate into a large SaaS platform.

Focus on engineering depth.

---

# 6. PRIMARY USER EXPERIENCE

## Example Scenario

A photographer receives a commercial photography project.

Project:

"Spring Campaign Photography"

Client:

"North Studio"

Project Value:

IDR 5,000,000

Deliverables:

- 100 photographs.
- 5 short videos.

The photographer creates a project in Slate.

The application generates a corresponding invoice.

The photographer imports media files from the iPhone
photo library.

The application begins uploading the selected media.

During the upload, the internet connection becomes unstable.

Some files upload successfully.

Other transfers are interrupted.

Slate must persist the upload state and recover
unfinished transfers without unnecessarily restarting
completed work.

The client receives a secure preview link.

The client reviews available preview images.

The client completes payment through a sandbox
payment checkout.

The backend verifies the payment through the
payment provider.

Once payment is confirmed and all required deliverables
have been successfully uploaded and verified,
the system enables final delivery.

The photographer can observe the status directly
from the native iOS application.

The client can then access the final deliverables.

All important operations must remain consistent
despite failures and repeated requests.

---

# 7. TECHNOLOGY STACK

## iOS

Language:
Swift

UI Framework:
UIKit

Architecture:
MVVM + Repository Pattern + Dependency Injection

Concurrency:
Swift async/await, Task, TaskGroup, Actors

Persistence:
Core Data

Networking:
URLSession

Background Transfer:
Background URLSession

Media Import:
PHPickerViewController and UIDocumentPickerViewController

Media Processing:
AVFoundation, Core Image, ImageIO

Cryptographic Hashing:
CryptoKit

Authentication Storage:
Keychain

Optional Biometric Protection:
LocalAuthentication

Network Monitoring:
Network Framework

Testing:
XCTest and XCUITest

Performance:
Xcode Instruments

## Backend

Runtime:
Node.js LTS

Language:
TypeScript

Framework:
Hono

Database:
PostgreSQL

ORM:
Prisma

Object Storage:
S3-compatible storage

Local Object Storage:
MinIO

Payments:
Sandbox payment provider through a provider adapter

Validation:
Zod or equivalent

Logging:
Structured logging

Testing:
Unit and integration tests

## Client Portal

Framework:
Next.js

Language:
TypeScript

Purpose:
Client previews, invoice viewing,
sandbox checkout, and secure media delivery.

The client portal must remain lightweight.

Do not allow the web portal to dominate
the implementation effort.

## Local Infrastructure

Use Docker Compose for:

- PostgreSQL.
- MinIO.
- Supporting infrastructure only when necessary.

Avoid Kubernetes and unnecessary microservices.

---

# 8. HIGH-LEVEL SYSTEM ARCHITECTURE

Design the system around three major components.

1. Native iOS Application.
2. Backend API.
3. Client Web Portal.

Conceptual architecture:

                    +----------------------+
                    |      Slate iOS       |
                    |----------------------|
                    | UIKit                |
                    | Project Management   |
                    | Transaction UI       |
                    | Transfer Engine      |
                    | Local Persistence    |
                    +----------+-----------+
                               |
                               | HTTPS
                               |
                    +----------v-----------+
                    |      Backend API     |
                    |----------------------|
                    | Authentication       |
                    | Projects             |
                    | Transactions         |
                    | Transfers            |
                    | Delivery Access      |
                    +-----+-----------+----+
                          |           |
                          v           v
                    PostgreSQL    Object Storage
                          |           |
                          |           |
                    +-----+-----------+----+
                    |    Client Portal     |
                    |----------------------|
                    | Project Preview      |
                    | Invoice              |
                    | Sandbox Checkout     |
                    | Secure Download      |
                    +----------------------+

## Architectural Rules

PostgreSQL is the authoritative source for:

- Project metadata.
- Invoice records.
- Payment status.
- Transfer metadata.
- Media verification state.
- Delivery authorization.
- Audit history.

Object storage is responsible for storing
media file content.

The iOS local database stores:

- Cached project data.
- Local transfer records.
- Transfer progress metadata.
- Pending local operations.
- Media staging references.
- Non-authoritative presentation state.

The iOS application must never become
the authoritative source of payment status.

Object storage must never become the authoritative
source of transaction status.

---

# 9. CORE DOMAIN MODEL

Design the following entities.

## User

Represents an authenticated creative professional.

Fields:

- id
- email
- passwordHash
- displayName
- createdAt
- updatedAt

Do not store plaintext passwords.

## Client

Represents a project customer.

Fields:

- id
- ownerId
- name
- email
- phone
- createdAt
- updatedAt

Client records must be scoped to their owner.

## Project

Represents a commercial media project.

Fields:

- id
- ownerId
- clientId
- title
- description
- status
- currency
- createdAt
- updatedAt
- version

## ProjectDeliverable

Represents expected project outputs.

Fields:

- id
- projectId
- title
- description
- expectedQuantity
- type
- createdAt

## Invoice

Represents an issued payment request.

Fields:

- id
- projectId
- invoiceNumber
- currency
- subtotalMinor
- totalMinor
- status
- issuedAt
- dueAt
- paidAt
- createdAt
- updatedAt
- version

All monetary values must use integer minor units.

Never use floating-point arithmetic for money.

For IDR, define and document the integer
amount representation consistently.

## InvoiceLineItem

Fields:

- id
- invoiceId
- description
- quantity
- unitPriceMinor
- lineTotalMinor

Server-side calculations must be authoritative.

## PaymentAttempt

Represents a payment operation associated
with an invoice.

Fields:

- id
- invoiceId
- provider
- providerReference
- amountMinor
- currency
- status
- idempotencyKey
- createdAt
- updatedAt

## PaymentEvent

Stores received payment provider events.

Fields:

- id
- paymentAttemptId
- providerEventId
- eventType
- payloadReference
- receivedAt
- processedAt
- processingStatus

Provider event identifiers must be unique
within the provider namespace.

## MediaAsset

Represents a media file.

Fields:

- id
- projectId
- ownerId
- filename
- mimeType
- sizeBytes
- contentHash
- storageKey
- status
- createdAt
- verifiedAt

## TransferSession

Represents a logical upload operation.

Fields:

- id
- mediaAssetId
- providerUploadId
- status
- totalBytes
- uploadedBytes
- partSize
- createdAt
- updatedAt
- expiresAt

## TransferPart

Represents an uploaded file part.

Fields:

- id
- transferSessionId
- partNumber
- sizeBytes
- storageETag
- checksum
- status

Enforce appropriate uniqueness constraints.

## DeliveryAccess

Represents access to final deliverables.

Fields:

- id
- projectId
- accessStatus
- issuedAt
- revokedAt
- expiresAt

## AuditEvent

Represents important state changes.

Fields:

- id
- entityType
- entityId
- action
- actorType
- actorId
- previousState
- newState
- createdAt
- correlationId

## IdempotencyRecord

Represents a previously processed logical request.

Fields:

- id
- ownerId
- operation
- idempotencyKey
- requestFingerprint
- status
- responseReference
- createdAt
- expiresAt

Additional tables are allowed when justified.

Avoid adding entities without clear responsibilities.

---

# 10. TRANSACTION ENGINE

This is one of the two most important
engineering components.

The Transaction Engine must demonstrate
correctness under concurrency, retries,
network failures, and duplicate events.

## 10.1 Financial Integrity Principles

The following rules are mandatory.

1. Never use floating-point money calculations.
2. Never trust payment status submitted by clients.
3. Never allow arbitrary payment state modification.
4. Never record the same logical payment twice.
5. Never rely on webhook delivery order.
6. Never assume a network timeout means failure.
7. Never perform duplicate financial side effects.
8. Never release deliverables based on optimistic UI state.
9. Never mutate historical financial records silently.
10. Every important transition must be auditable.

Financial correctness must be enforced by the backend.

The native iOS application displays
server-authoritative information.

---

# 11. INVOICE STATE MACHINE

Implement explicit invoice states.

Suggested states:

DRAFT
ISSUED
PAID
VOID

An issued but unpaid invoice may also be overdue.

Prefer deriving overdue information from
the due date and current state unless
a persisted overdue state is justified.

## Allowed Transitions

DRAFT -> ISSUED

DRAFT -> VOID

ISSUED -> PAID

ISSUED -> VOID

## Important Rules

PAID invoices cannot return to DRAFT.

PAID invoices cannot be silently deleted.

Paid invoices cannot simply become VOID.

Refunds, if introduced later, must be modeled
as separate financial operations.

Invoice amounts must be finalized before issuance.

Once issued, monetary details must not be
silently modified.

If corrections are required, use an explicit
revision or replacement process.

Do not implement complex tax or refund workflows
during the MVP.

## Invoice Number Generation

Invoice numbers must be generated server-side.

Use a collision-safe generation strategy.

Database uniqueness constraints must enforce
invoice number uniqueness.

Do not derive invoice numbers from
the local iOS clock.

---

# 12. PAYMENT STATE MACHINE

Model payment attempts separately from invoices.

Suggested payment attempt states:

CREATED
PENDING
SUCCEEDED
FAILED
EXPIRED

## State Rules

A successful payment must be verified
through the payment provider.

Terminal status changes must follow
provider-specific rules.

Do not assume that all payment providers
use identical state transitions.

Do not automatically overwrite SUCCEEDED
with EXPIRED because an old event arrived later.

If contradictory events arrive:

- Preserve the verified historical record.
- Query the provider when needed.
- Reconcile the current state.
- Record the resolution.

The system must never determine payment success
from client navigation or a success animation.

## Payment Source of Truth

The authoritative payment information comes from:

1. Verified provider notifications.
2. Authenticated provider API verification.
3. Reconciliation against provider records.

The client portal may initiate checkout.

The iOS application only displays
the resulting authoritative state.

---

# 13. PAYMENT PROVIDER INTEGRATION

Implement payment integration using sandbox mode.

Use an established provider with a documented
sandbox environment.

Examples:

- Midtrans Sandbox.
- Xendit Test Mode.
- Stripe Test Mode.

Choose one provider based on current documentation,
regional availability, and implementation suitability.

Do not integrate multiple providers unless necessary.

## Provider Adapter

Create a payment provider abstraction.

Suggested interface responsibilities:

- Create payment session.
- Retrieve payment status.
- Verify webhook signature.
- Normalize provider status.
- Retrieve provider transaction reference.

The provider adapter must translate external statuses
into the application's domain model.

Keep provider-specific behavior isolated.

## Local Testing

Provide a deterministic local payment simulator
for automated testing.

The simulator must be explicitly marked as
development-only.

Simulated payments must never be mistaken
for verified production payments.

Never expose development payment controls
in production builds.

## App Store Compliance

The product represents invoicing for
professional creative services.

Before production distribution, evaluate
the actual payment model against
current Apple App Review Guidelines.

Do not assume that moving digital-content
checkout to a website automatically
avoids In-App Purchase requirements.

Keep sandbox payment testing separate
from production payment capabilities.

---

# 14. IDEMPOTENCY

Implement idempotency for critical operations.

Required operations include:

- Project creation where duplicate retries matter.
- Invoice issuance.
- Payment session creation.
- Payment webhook processing.
- Transfer session creation.
- Multipart upload finalization.
- Final delivery release.

## Client Requests

For supported operations, clients generate
an idempotency key.

Example:

Idempotency-Key: <UUID>

The backend associates the key with:

- Authenticated owner.
- Operation type.
- Request fingerprint.
- Stored operation result.

Repeated requests with the same key and payload
must not duplicate the logical operation.

Reusing the same key with a different payload
must return a conflict.

The server must enforce this using
database constraints and transactional logic.

An in-memory map is insufficient.

## Crash Safety

Handle failures where:

- The database commit succeeds.
- The HTTP response is lost.
- The client retries.

The retry must resolve to the existing
logical operation rather than creating another one.

Do not rely solely on HTTP retry logic.

---

# 15. DATABASE TRANSACTIONS

Use PostgreSQL transactions for operations
requiring atomic database updates.

Examples:

- Issuing an invoice.
- Recording verified payment completion.
- Updating related invoice status.
- Recording payment event processing.
- Creating delivery authorization records.

## Transaction Requirements

Use Prisma transactions where appropriate.

Implement concurrency protection using
optimistic version checks, conditional updates,
or row-level locking when justified.

Choose the strategy based on actual data access patterns.

Database-level constraints must protect critical invariants.

Do not rely exclusively on application-level checks.

## Example Invariant

A payment attempt must not be applied twice.

A valid implementation should protect this invariant
even when two workers process duplicate payment events
at approximately the same time.

## Important Boundary

A PostgreSQL transaction cannot atomically commit
an external payment provider operation
and an object storage operation.

Do not pretend that distributed operations
are covered by one ACID transaction.

Use durable state transitions,
idempotent processing, and reconciliation.

---

# 16. PAYMENT WEBHOOK PROCESSING

Implement secure webhook processing.

## Required Workflow

1. Receive webhook.
2. Verify provider signature.
3. Validate payload.
4. Identify provider event.
5. Deduplicate previously processed events.
6. Persist accepted event information.
7. Update payment state transactionally.
8. Update invoice state when justified.
9. Trigger delivery eligibility evaluation.
10. Record the result.

## Important Properties

Webhook processing must be idempotent.

Webhook events may be duplicated.

Webhook events may arrive out of order.

The provider may retry events.

A backend restart must not cause
duplicate payment application.

## Error Handling

If processing fails after an event is accepted,
the system must support retrying it safely.

Do not acknowledge successful processing
when critical state changes were never persisted.

Use a durable inbox or equivalent strategy
when needed to separate webhook receipt
from downstream processing.

## Reconciliation

Implement a mechanism to reconcile
payment attempts with provider state.

This is required because webhook delivery
must not be treated as the only possible
source of payment updates.

---

# 17. RELIABLE MEDIA TRANSFER ENGINE

This is the second primary engineering component.

It must demonstrate advanced native iOS capabilities.

## Primary Objective

Transfer large media files reliably while:

- Preserving progress.
- Avoiding unnecessary retransmission.
- Surviving recoverable network failures.
- Respecting iOS lifecycle restrictions.
- Preventing corrupted file delivery.
- Maintaining accurate transfer states.

Do not implement the transfer engine as
a simple single-request upload feature.

---

# 18. MEDIA IMPORT

Use native iOS media selection APIs.

Support:

- Images.
- Videos.
- Supported files from the Files application.

Preferred:

- PHPickerViewController.
- UIDocumentPickerViewController.

Avoid requesting full photo-library access
when a system picker is sufficient.

## Import Requirements

When the user selects media:

1. Validate the file type.
2. Obtain a durable local file reference.
3. Stage the file inside app-controlled storage.
4. Extract required metadata.
5. Determine file size.
6. Create a local transfer record.
7. Prepare the file for upload.

## File Metadata

Extract:

- Filename.
- MIME type.
- File size.
- Image dimensions where applicable.
- Video duration where applicable.
- Creation metadata when available.

Do not require unnecessary access
to sensitive metadata.

## Large File Handling

Never load an entire large video
into memory unnecessarily.

Prefer file-based operations.

Use streaming or chunked processing
where appropriate.

For imported files, respect security-scoped resource
access and file coordination requirements.

Once an upload is queued, ensure that the
required source bytes remain available even
after the external file-provider access ends.

---

# 19. TRANSFER STATE MACHINE

Implement a persistent transfer state machine.

Suggested states:

QUEUED
PREPARING
READY
UPLOADING
PAUSED
RETRY_WAITING
VERIFYING
COMPLETED
FAILED
CANCELLED

## Typical Transitions

QUEUED -> PREPARING

PREPARING -> READY

READY -> UPLOADING

UPLOADING -> PAUSED

PAUSED -> UPLOADING

UPLOADING -> RETRY_WAITING

RETRY_WAITING -> UPLOADING

UPLOADING -> VERIFYING

VERIFYING -> COMPLETED

VERIFYING -> FAILED

FAILED -> RETRY_WAITING

QUEUED -> CANCELLED

PAUSED -> CANCELLED

FAILED -> CANCELLED

The state model may be refined during implementation.

## State Ownership

A dedicated TransferCoordinator or equivalent
component must own transfer scheduling.

Use actor isolation when coordinating
shared mutable transfer state.

Do not allow multiple view controllers
to independently schedule uploads.

The UI must observe transfer state.

The UI must not become the owner
of transfer correctness.

## State Persistence

Persist meaningful transfer transitions.

An application restart must not lose
the logical transfer queue.

---

# 20. RESUMABLE MULTIPART UPLOAD

Use an established resumable transfer mechanism.

For the MVP, prefer S3-compatible multipart upload
coordinated by the backend.

Do not invent an entirely custom transport protocol
without justification.

## Upload Workflow

1. Client selects a file.
2. Client stages the file.
3. Client calculates or schedules integrity metadata.
4. Client requests a transfer session.
5. Backend initializes multipart upload.
6. Backend returns upload session metadata.
7. Client uploads file parts.
8. Successful part metadata is persisted.
9. Interrupted parts are retried.
10. Client requests upload reconciliation.
11. Backend verifies completed parts.
12. Backend completes multipart upload.
13. Backend verifies the resulting object.
14. Media status becomes VERIFIED.
15. Delivery eligibility is reevaluated.

## Upload Part Strategy

Use a configurable part size.

Start with a reasonable multipart part size,
such as 8 MiB, when supported by storage constraints.

Respect the storage provider's multipart requirements.

Avoid creating excessive numbers of tiny parts.

The last part may be smaller.

Do not load all parts into memory.

Prepare file-backed upload parts when required
by background URLSession behavior.

## Concurrency Control

Use bounded upload concurrency.

A reasonable initial configuration is
two or three concurrent part uploads.

The exact limit must be configurable.

Do not assume higher concurrency
always improves throughput.

Consider:

- Network conditions.
- Memory usage.
- File I/O.
- Thermal behavior.
- Battery consumption.
- Backend limitations.

---

# 21. BACKGROUND UPLOAD

Implement background transfer using URLSession.

Use a persistent background session identifier.

## Requirements

- Background URLSession configuration.
- File-backed upload tasks.
- Persistent mapping between tasks and transfer records.
- Completion handling through URLSession delegates.
- Application relaunch reconciliation.
- Transfer status restoration.
- Controlled concurrency.

Do not use Data-based background upload tasks
for large media files that must survive
normal application suspension.

## Application Lifecycle

Handle:

- App foregrounding.
- App backgrounding.
- System termination.
- Application relaunch.
- Network interruption.
- User-initiated force quit.

## Important Limitation

Background transfers are managed by iOS.

The system does not guarantee
immediate execution or continuous processing.

User-initiated force quit may cancel background transfers
and prevent automatic relaunch.

Slate must persist enough information
to recover the workflow when the user
opens the application again.

Do not claim that uploads always continue
after force quit.

## Task Reconciliation

When the application resumes:

1. Restore the local transfer queue.
2. Reconnect to the background session.
3. Enumerate available URLSession tasks.
4. Match tasks with persistent transfer records.
5. Query the backend for authoritative part status.
6. Reconcile discrepancies.
7. Resume eligible operations.

Do not assume that locally recorded progress
always matches server progress.

---

# 22. FILE INTEGRITY VERIFICATION

Implement end-to-end integrity checks.

Use CryptoKit where appropriate.

Prefer a clearly documented checksum strategy.

## Requirements

- Validate the imported file.
- Calculate an appropriate content hash.
- Store expected integrity metadata.
- Verify upload completion.
- Confirm the final object matches expected data.

For portfolio-sized media files,
streaming SHA-256 is an appropriate demonstration.

Do not load entire large files into memory
just to calculate a hash.

## Important Storage Detail

Do not assume an S3 multipart ETag
is the MD5 checksum of the complete file.

Use explicit integrity verification.

Where supported, use storage-provider
checksum validation.

Otherwise, implement a backend verification process
that computes or validates the complete object's
expected digest.

## Corrupted File Scenario

If integrity verification fails:

- Mark the asset as invalid.
- Prevent final delivery.
- Preserve diagnostic information.
- Provide a recovery action.
- Retry or reupload according to policy.

Never mark a file as successfully delivered
only because an HTTP upload request returned success.

---

# 23. RETRY AND FAILURE RECOVERY

Implement explicit retry behavior.

## Retryable Failures

Examples:

- Temporary network disconnection.
- HTTP 429.
- HTTP 503.
- Recoverable timeouts.
- Temporary storage service failures.

## Non-Retryable Failures

Examples:

- Unsupported file type.
- Permanent authorization failure.
- Invalid project ownership.
- Explicitly cancelled transfer.
- Exceeded configured file-size limit.

## Retry Strategy

Use bounded exponential backoff with jitter.

Respect Retry-After headers where applicable.

Avoid aggressive infinite retry loops.

Persist retry metadata when necessary.

## Expired Upload URLs

Signed upload URLs may expire.

When this occurs:

- Do not discard the entire transfer immediately.
- Request refreshed upload authorization.
- Reconcile previously completed parts.
- Continue the remaining upload.

## Upload Session Expiration

If an upload session is no longer recoverable:

- Mark it appropriately.
- Explain the situation.
- Allow a safe restart.
- Clean up abandoned storage resources.

Provide a backend cleanup mechanism
for stale multipart uploads.

---

# 24. OFFLINE-FIRST ARCHITECTURE

Slate must remain useful without internet access.

However, offline-first does not mean
inventing financial confirmation locally.

## Available Offline

Users should be able to:

- View previously cached projects.
- Create local project drafts.
- Review staged media.
- Queue media transfers.
- Inspect local transfer progress.
- Modify safe local draft metadata.

## Requires Backend Confirmation

Operations that require authoritative server state include:

- Invoice issuance.
- Payment confirmation.
- Final delivery authorization.
- Final transfer verification.
- Server-side project completion.

## Offline Operation Queue

Use a durable local operation queue
for supported offline mutations.

Each operation should include:

- Operation ID.
- Entity ID.
- Operation type.
- Payload.
- Created timestamp.
- Idempotency key.
- Retry count.
- Synchronization status.

Avoid treating every offline mutation identically.

Classify operations according to their
business consequences.

## Synchronization

When connectivity returns:

1. Determine pending operations.
2. Validate current authentication.
3. Fetch relevant server state.
4. Submit eligible operations.
5. Apply idempotency.
6. Resolve conflicts.
7. Update local persistence.

Do not silently overwrite newer server data.

---

# 25. LOCAL PERSISTENCE

Use Core Data for persistent application state.

The local database should contain:

- Cached projects.
- Cached clients.
- Cached invoice snapshots.
- Local media assets.
- Transfer records.
- Pending operations.
- Retry metadata.

## Data Ownership

Distinguish between:

1. Local authoritative state.
2. Server authoritative state.
3. Cached read-only projections.

For example:

A queued local upload task can be authoritative
for local scheduling.

An invoice payment status cannot be
authoritative when stored only on the device.

## Data Migration

Use a migration-friendly persistence schema.

Avoid destructive database recreation
as a normal application update strategy.

## Concurrency

Respect Core Data context confinement.

Do not share managed objects across
concurrency boundaries unsafely.

Prefer passing stable identifiers
or immutable value representations.

---

# 26. PROJECT WORKFLOW STATE MACHINE

Model project progress independently
from payment and media transfer states.

Suggested states:

DRAFT
CONFIRMED
IN_PROGRESS
READY_FOR_DELIVERY
DELIVERED
COMPLETED
CANCELLED

## Project Rules

A project may contain multiple deliverables.

A project may have an invoice.

A project may contain multiple media assets.

A project may not become ready for delivery
until required deliverables are verified.

A project may not become completed
merely because payment succeeded.

## State Transition Validation

Transitions must be validated server-side.

Use a centralized domain service.

Do not distribute transition rules
across unrelated route handlers.

Reject invalid transitions.

Maintain an audit record.

---

# 27. DELIVERY AUTHORIZATION ENGINE

This component connects the Transaction Engine
and Media Transfer Engine.

## Objective

Ensure final media access is granted
only when all applicable business conditions
are satisfied.

## MVP Delivery Policy

Final delivery requires:

1. Project is eligible for delivery.
2. Required media assets are verified.
3. Invoice is fully paid.
4. Client is authorized.
5. Delivery access has not been revoked.

## Example Matrix

Payment: PENDING
Assets: VERIFIED
Result: LOCKED

Payment: SUCCEEDED
Assets: UPLOADING
Result: NOT_READY

Payment: SUCCEEDED
Assets: FAILED
Result: NOT_READY

Payment: SUCCEEDED
Assets: VERIFIED
Result: ELIGIBLE

Payment: SUCCEEDED
Assets: VERIFIED
Access: REVOKED
Result: LOCKED

The backend must evaluate this policy.

The iOS application may display
a projected delivery status.

It must not independently grant access.

## Authorization Model

Use explicit access checks.

Do not treat possession of a predictable
project identifier as authorization.

Final files must remain private
in object storage.

Issue short-lived authorized download URLs
only after server-side access validation.

## Payment and Delivery Race Conditions

Handle cases where:

- Payment completes before uploads.
- Uploads complete before payment.
- Webhooks are duplicated.
- Media verification finishes concurrently
  with payment processing.
- The backend crashes during delivery release.

The final eligible state must be reached
without requiring a particular event order.

Use idempotent reevaluation of delivery eligibility.

---

# 28. CONSISTENCY ACROSS SYSTEMS

The system coordinates:

- PostgreSQL.
- Payment provider.
- Object storage.
- Native iOS local persistence.

These systems do not share
one global ACID transaction.

## Required Consistency Model

Use strong transactional consistency
for critical database invariants.

Use controlled eventual consistency
for external operations.

## Example

Payment succeeds.

The database records payment completion.

Media verification is still pending.

The system must not issue a final download URL.

After media verification succeeds,
delivery eligibility is evaluated again.

If a worker crashes between these operations,
the system must recover.

## Durable Processing

Use a transactional outbox or an equivalent
durable mechanism when asynchronous processing
is required to maintain critical invariants.

Keep the implementation proportional to the MVP.

A single backend service with a small durable worker
is sufficient.

Do not introduce Kafka or complex infrastructure
without a demonstrated need.

## Reconciliation

Implement a reconciliation process for:

- Unprocessed payment events.
- Pending payment attempts.
- Incomplete multipart uploads.
- Uploads completed in storage but not finalized in DB.
- Delivery eligibility awaiting reevaluation.

The process must be safe to run repeatedly.

---

# 29. NATIVE iOS APPLICATION ARCHITECTURE

Use UIKit as the primary UI framework.

Preferred architecture:

MVVM + Repository Pattern + Dependency Injection.

Suggested project structure:

Slate/
|
+-- apps/
|   |
|   +-- ios/
|   |   |
|   |   +-- Slate/
|   |   |   |
|   |   |   +-- App/
|   |   |   |   +-- AppDelegate
|   |   |   |   +-- SceneDelegate
|   |   |   |   +-- AppCoordinator
|   |   |   |   +-- DependencyContainer
|   |   |   |
|   |   |   +-- Presentation/
|   |   |   |   +-- Authentication/
|   |   |   |   +-- Dashboard/
|   |   |   |   +-- Projects/
|   |   |   |   +-- Invoices/
|   |   |   |   +-- Transfers/
|   |   |   |   +-- MediaGallery/
|   |   |   |   +-- Settings/
|   |   |   |   +-- Components/
|   |   |   |
|   |   |   +-- Domain/
|   |   |   |   +-- Models/
|   |   |   |   +-- UseCases/
|   |   |   |   +-- RepositoryProtocols/
|   |   |   |   +-- StateMachines/
|   |   |   |
|   |   |   +-- Data/
|   |   |   |   +-- Network/
|   |   |   |   +-- Local/
|   |   |   |   +-- Repositories/
|   |   |   |
|   |   |   +-- Transfer/
|   |   |   |   +-- TransferCoordinator
|   |   |   |   +-- BackgroundSessionManager
|   |   |   |   +-- MultipartUploadManager
|   |   |   |   +-- TransferPersistence
|   |   |   |   +-- IntegrityVerifier
|   |   |   |   +-- RetryPolicy
|   |   |   |
|   |   |   +-- Media/
|   |   |   |   +-- MediaImportService
|   |   |   |   +-- ThumbnailService
|   |   |   |   +-- MediaMetadataService
|   |   |   |
|   |   |   +-- Security/
|   |   |   |   +-- KeychainManager
|   |   |   |   +-- AuthenticationManager
|   |   |   |
|   |   |   +-- Resources/
|   |   |
|   |   +-- SlateTests/
|   |   +-- SlateUITests/
|   |
|   +-- client-web/
|
+-- services/
|   +-- api/
|       +-- src/
|       |   +-- modules/
|       |   |   +-- auth/
|       |   |   +-- projects/
|       |   |   +-- invoices/
|       |   |   +-- payments/
|       |   |   +-- transfers/
|       |   |   +-- delivery/
|       |   |
|       |   +-- infrastructure/
|       |   +-- middleware/
|       |   +-- jobs/
|       |
|       +-- tests/
|
+-- packages/
|   +-- database/
|       +-- prisma/
|
+-- infrastructure/
|   +-- docker-compose.yml
|
+-- docs/
|   +-- architecture/
|   +-- ios/
|   +-- transactions/
|   +-- transfers/
|   +-- testing/
|   +-- portfolio/
|
+-- README.md

Adjust the structure when necessary.

Do not create directories that contain
no meaningful implementation.

Avoid excessive architectural fragmentation.

---

# 30. SWIFT CONCURRENCY REQUIREMENTS

Use Swift Concurrency deliberately.

Do not use async/await only as syntactic decoration.

## Required Concepts

- Structured concurrency.
- Main-actor isolation.
- Actor-based shared state protection.
- Task cancellation.
- Async error propagation.
- Controlled parallelism.

## Main Actor

UIKit operations must execute
on the appropriate main-actor context.

Do not perform expensive media operations
on the main thread.

## Transfer Coordination

Use an actor or equivalent synchronized component
to manage shared transfer scheduling state.

Prevent:

- Duplicate scheduling.
- Conflicting state updates.
- Race conditions.
- Invalid task ownership.

## Cancellation

Distinguish between:

- Cancelling an individual network task.
- Pausing a logical transfer.
- Cancelling the entire upload session.
- Deleting a media asset.

These operations are not equivalent.

Implement explicit semantics for each.

## Task Lifecycle

Avoid detached tasks without clear ownership.

Ensure asynchronous operations
can be cancelled when no longer needed.

Do not accidentally cancel important
system-managed background transfers
when a view controller disappears.

---

# 31. USER INTERFACE DESIGN

## Design Philosophy

Slate should feel like a professional iOS application
designed for creative professionals.

Visual characteristics:

- Minimal.
- Precise.
- Elegant.
- Calm.
- Functional.
- High information clarity.
- Excellent typography.
- Restrained animation.

Avoid generic admin-dashboard aesthetics.

Avoid excessive card nesting.

Avoid overwhelming users with metrics.

## Design System

Suggested palette:

Background:
#F8F8F6

Surface:
#FFFFFF

Primary Text:
#191919

Secondary Text:
#707070

Border:
#E5E5E2

Primary Accent:
#556B62

Success:
#4F8868

Warning:
#C79035

Error:
#C75A52

Dark Surface:
#242625

Use semantic colors where possible.

Support system appearance when appropriate.

## Typography

Use Apple's system typography.

Establish a consistent hierarchy:

- Display title.
- Screen title.
- Section heading.
- Body.
- Supporting information.
- Metadata.
- Caption.

Support Dynamic Type.

## Navigation

Use native UIKit navigation patterns.

Prefer:

- UINavigationController.
- UITabBarController where justified.
- UICollectionView.
- UIStackView.
- Native sheets.
- Context menus.
- Swipe actions when appropriate.

Avoid custom navigation
when native navigation is sufficient.

---

# 32. REQUIRED SCREENS

## 32.1 Authentication

Provide:

- Login.
- Registration.
- Logout.
- Session restoration.

Authentication must be functional.

Do not use hardcoded production credentials.

Provide a documented local demo account
through development seed data.

## 32.2 Dashboard

Display:

- Active projects.
- Pending invoices.
- Active transfers.
- Projects ready for delivery.
- Recent activity.

Keep the dashboard concise.

## 32.3 Project List

Display:

- Project title.
- Client.
- Project status.
- Payment status.
- Delivery status.

Support search and basic filtering.

## 32.4 Project Detail

Display:

- Client information.
- Deliverables.
- Invoice status.
- Media assets.
- Upload progress.
- Delivery readiness.
- Activity history.

This is the central workflow screen.

## 32.5 Create Project

Support:

- Title.
- Client selection.
- Description.
- Deliverables.
- Project value.

Validate required fields.

Allow safe draft creation offline.

## 32.6 Invoice Detail

Display:

- Invoice number.
- Amount.
- Currency.
- Status.
- Due date.
- Line items.
- Payment history.

Do not provide a client-side
"Mark Payment Successful" button.

## 32.7 Transfer Manager

Display:

- Queued files.
- Active transfers.
- Progress percentage.
- Upload speed when measurable.
- Retry state.
- Verification state.
- Completed transfers.
- Failed transfers.

Provide:

- Pause.
- Resume.
- Retry.
- Cancel.

Actions must reflect actual transfer semantics.

## 32.8 Media Gallery

Display:

- Media thumbnails.
- File metadata.
- Transfer verification status.
- Preview availability.

Use efficient lazy loading.

## 32.9 Delivery Screen

Display:

- Payment readiness.
- Upload readiness.
- Verification readiness.
- Final delivery status.
- Secure client link.

Explain why delivery is blocked.

## 32.10 Settings

Provide:

- Account management.
- Logout.
- Transfer preferences.
- Cellular upload preferences.
- Cache management.
- App information.

Avoid unnecessary settings.

---

# 33. TRANSACTION UX REQUIREMENTS

Payment-related UI must avoid misleading users.

## Required States

- Loading.
- Pending.
- Paid.
- Failed payment attempt.
- Expired payment attempt.
- Unable to verify.
- Offline.

## Important UX Rules

Do not show success solely
because a checkout page was closed.

Do not show success based on
an unverified client callback.

Display pending status when
backend verification is incomplete.

Use clear explanations.

Example:

"Payment confirmation is pending."

Avoid technical error messages such as:

"Webhook processing failed with HTTP 500."

Provide a refresh or retry action
when appropriate.

Always display authoritative status
after reconciliation with the backend.

---

# 34. TRANSFER UX REQUIREMENTS

The transfer interface must communicate
the real state of each upload.

Distinguish between:

- Uploading bytes.
- Waiting for network.
- Retrying.
- Waiting for verification.
- Fully completed.

Do not display 100% complete
as final success before verification finishes.

A transfer can finish uploading bytes
while still requiring server verification.

Suggested presentation:

"Upload complete — verifying file"

Progress must not falsely reset to zero
when the application restarts.

When server reconciliation changes
the known uploaded amount, update the
display with a clear status explanation.

Use accessible progress indicators.

Avoid excessive animation.

---

# 35. AUTHENTICATION AND SECURITY

Implement creator authentication.

## Password Handling

Use secure password hashing on the server.

Never store plaintext passwords.

Use a well-supported password hashing strategy.

## Token Storage

Store sensitive session credentials
using iOS Keychain.

Do not store access tokens in UserDefaults.

## Session Management

Implement:

- Token expiration.
- Safe refresh or reauthentication.
- Logout.
- Revocation handling.
- Unauthorized response handling.

Avoid uncontrolled duplicate refresh requests.

## Authorization

Every backend operation must verify
the authenticated user's permissions.

Users must not access projects,
invoices, or media belonging to other accounts.

## Object Storage

Buckets containing private media
must not be publicly readable.

Never embed object storage credentials
inside the iOS application.

Use short-lived signed URLs
for authorized operations.

## Client Portal

Use secure, unguessable access tokens
or another appropriate authentication model.

Access tokens must be revocable.

Do not expose final files through
permanent public URLs.

Apply rate limiting where appropriate.

---

# 36. API DESIGN

Create RESTful APIs under:

/api/v1

## Authentication

POST /auth/register

POST /auth/login

POST /auth/refresh

POST /auth/logout

GET /auth/me

## Clients

GET /clients

POST /clients

GET /clients/:id

PATCH /clients/:id

## Projects

GET /projects

POST /projects

GET /projects/:id

PATCH /projects/:id

POST /projects/:id/confirm

POST /projects/:id/complete

## Invoices

POST /projects/:id/invoices

GET /invoices/:id

POST /invoices/:id/issue

POST /invoices/:id/void

## Payments

POST /invoices/:id/payment-session

GET /invoices/:id/payment-status

POST /webhooks/payments/:provider

## Media

GET /projects/:id/media

POST /projects/:id/media

GET /media/:id

## Transfers

POST /transfers

GET /transfers/:id

GET /transfers/:id/parts

POST /transfers/:id/parts/authorization

POST /transfers/:id/complete

POST /transfers/:id/abort

## Delivery

GET /projects/:id/delivery

POST /projects/:id/delivery/release

POST /projects/:id/delivery/revoke

## Client Portal

GET /client/projects/:token

GET /client/projects/:token/preview

GET /client/projects/:token/invoice

POST /client/projects/:token/checkout

GET /client/projects/:token/downloads

GET /client/projects/:token/downloads/:assetId

The endpoint structure may be refined.

Do not implement unnecessary endpoints.

## API Requirements

- Consistent response models.
- Clear HTTP status codes.
- Input validation.
- Authentication.
- Authorization.
- Request size limits.
- Idempotency where required.
- Pagination.
- Error mapping.
- Structured logging.
- Rate limiting for sensitive routes.

Use typed contracts where practical.

Do not expose internal stack traces.

---

# 37. CLIENT WEB PORTAL

Implement a lightweight web portal.

The portal is not a full administrative application.

## Required Capabilities

1. Open secure project link.
2. View project information.
3. View approved media previews.
4. View invoice.
5. Open sandbox checkout.
6. Observe verified payment status.
7. Download authorized final deliverables.

## Preview Security

Preview assets may be lower-resolution
or watermarked versions of original files.

Do not expose original storage keys.

Preview authorization must be distinct
from final-delivery authorization.

Do not rely on UI visibility
to protect final files.

## Payment

Use the selected provider's sandbox checkout.

Do not collect raw payment card credentials
directly through custom backend forms.

Use established provider-hosted
or provider-supported checkout mechanisms.

## Delivery

Generate short-lived download URLs
after verifying access.

Never expose unrestricted public buckets.

---

# 38. TESTING STRATEGY

Testing is mandatory.

Do not treat testing as a final optional phase.

Implement tests throughout development.

## 38.1 iOS Unit Tests

Test:

- View model state transitions.
- Project validation.
- Invoice decoding.
- Error mapping.
- Transfer state transitions.
- Retry policy.
- Progress calculations.
- Synchronization behavior.
- Task reconciliation logic.
- Cache behavior.
- Local persistence.

## 38.2 Concurrency Tests

Test:

- Duplicate transfer scheduling.
- Simultaneous state updates.
- Task cancellation.
- Actor-isolated state mutation.
- Concurrent upload completion callbacks.
- Repeated retry requests.

## 38.3 Backend Transaction Tests

Test:

- Invoice issuance.
- Duplicate invoice issuance.
- Concurrent invoice issuance.
- Idempotency key reuse.
- Conflicting idempotency payloads.
- Duplicate payment webhook.
- Out-of-order payment events.
- Concurrent webhook processing.
- Payment status reconciliation.
- Invalid payment transitions.

Use real PostgreSQL integration tests
for important database consistency behavior.

Mocks alone are insufficient
to demonstrate transactional correctness.

## 38.4 Transfer Tests

Test:

- Successful multipart upload.
- Interrupted upload.
- Resumed upload.
- Expired signed URL.
- Failed part upload.
- Missing part.
- Duplicate part completion.
- Upload cancellation.
- Invalid checksum.
- Backend restart.
- App state restoration.
- Reconciliation after ambiguous responses.

## 38.5 Delivery Tests

Test:

- Unpaid project cannot release final files.
- Unverified media cannot be delivered.
- Paid and verified project becomes eligible.
- Revoked access cannot download files.
- Unauthorized users cannot access media.
- Concurrent payment and upload completion.
- Duplicate delivery release.
- Storage verification failure.

## 38.6 UI Tests

Test:

- Authentication flow.
- Project creation.
- Invoice navigation.
- Media selection flow where automatable.
- Transfer state presentation.
- Offline error presentation.
- Delivery status presentation.

## 38.7 Physical Device Tests

Test actual iOS behavior on a physical iPhone.

Required scenarios:

- Import multiple photographs.
- Import a large video.
- Start uploads.
- Lock the device.
- Background the application.
- Restore the application.
- Disconnect the network.
- Reconnect the network.
- Change between Wi-Fi and cellular where practical.
- Force quit and reopen.
- Cancel a transfer.
- Retry a failed transfer.
- Inspect memory usage.

Do not claim physical-device verification
without performing it.

---

# 39. FAILURE INJECTION TESTING

Create a reproducible development test harness.

The test harness should simulate
realistic failures.

## Scenario A — Network Failure

Interrupt a transfer after partial completion.

Expected:

Previously confirmed parts remain valid.

The transfer can resume safely.

## Scenario B — Backend Failure

Restart the backend during upload finalization.

Expected:

The upload can be reconciled.

No duplicate finalized media record is created.

## Scenario C — Duplicate Payment Event

Deliver the same verified payment event multiple times.

Expected:

Only one logical payment application occurs.

## Scenario D — Concurrent Operations

Process payment confirmation and media verification
at approximately the same time.

Expected:

Delivery becomes eligible only when
all requirements are satisfied.

## Scenario E — Invalid File Integrity

Provide a mismatched expected checksum.

Expected:

The file is rejected from final delivery.

## Scenario F — Application Relaunch

Terminate normal app execution
and reopen the application.

Expected:

Persistent transfer records are restored.

The application reconciles
outstanding upload tasks.

## Scenario G — Ambiguous API Timeout

Allow a server operation to commit,
but prevent the client from receiving the response.

Expected:

Client retries using the same idempotency key.

The server returns the existing logical result.

## Scenario H — Unauthorized Download

Attempt to access an original media file
without valid delivery authorization.

Expected:

The backend denies access.

Do not use public object storage URLs.

---

# 40. PERFORMANCE ENGINEERING

Measure actual performance.

Do not fabricate benchmarks.

## Primary Metrics

- Application launch responsiveness.
- Memory consumption.
- CPU utilization.
- Media import latency.
- Upload throughput.
- Transfer recovery time.
- Main-thread responsiveness.
- Thumbnail generation cost.
- Database query performance.

## Large File Targets

Use representative test files.

Suggested test categories:

Small:
5–20 MB

Medium:
100–300 MB

Large:
500 MB–1 GB

The system should be designed for larger files,
but do not claim a specific maximum supported size
without verifying it.

## Memory Management

Avoid loading entire videos into memory.

Avoid retaining unnecessary UIImage instances.

Use thumbnail caching.

Release temporary processing resources.

Clean up staged files
when no longer required.

Do not delete files that are still needed
by pending background URLSession tasks.

## Battery and Thermal Considerations

Use bounded concurrency.

Avoid unnecessary repeated hashing.

Avoid continuous polling.

Respect cellular transfer preferences.

Use efficient file I/O.

---

# 41. OBSERVABILITY

Implement structured logging.

Important operations should contain
correlation identifiers.

Examples:

- Project ID.
- Invoice ID.
- Payment attempt ID.
- Transfer session ID.
- Upload part number.
- Request ID.

## Log Important Events

- Invoice issued.
- Payment webhook accepted.
- Payment state updated.
- Transfer started.
- Part upload failed.
- Transfer resumed.
- File verification completed.
- Delivery released.
- Access revoked.

## Privacy Rules

Do not log:

- Passwords.
- Access tokens.
- Payment secrets.
- Full signed URLs.
- Raw private media.
- Sensitive customer information unnecessarily.

Use appropriate redaction.

## Portfolio Demonstration

Provide a development-only diagnostic view
or structured test output that demonstrates
system behavior.

Do not create a large observability dashboard.

---

# 42. DEVELOPMENT PHASES

Implement incrementally.

Each phase must produce a verifiable result.

## PHASE 1 — Architecture and Foundation

Objectives:

- Inspect the repository.
- Inspect available development tools.
- Establish the monorepo.
- Create the native iOS project.
- Configure UIKit.
- Implement dependency injection.
- Establish domain models.
- Configure backend infrastructure.

Acceptance:

The application launches.

The backend starts.

Database migrations work.

## PHASE 2 — Native Application Foundation

Objectives:

- Authentication screens.
- Session management.
- Dashboard.
- Project list.
- Project detail.
- Basic navigation.
- Local persistence.

Acceptance:

The application supports authenticated
project navigation.

## PHASE 3 — Project and Invoice Engine

Objectives:

- Project creation.
- Client management.
- Invoice creation.
- Invoice state machine.
- Database transactions.
- Idempotency.
- Audit events.

Acceptance:

Invoices are created consistently.

Duplicate requests are safe.

## PHASE 4 — Payment Orchestration

Objectives:

- Payment provider adapter.
- Sandbox checkout.
- Webhook verification.
- Payment state transitions.
- Event deduplication.
- Payment reconciliation.

Acceptance:

Sandbox payments update invoices
without client-side payment authority.

## PHASE 5 — Media Import

Objectives:

- Photo selection.
- File selection.
- Durable local staging.
- Metadata extraction.
- Transfer record persistence.
- Media preview generation.

Acceptance:

Selected files remain available
for queued upload operations.

## PHASE 6 — Transfer Engine

Objectives:

- Multipart upload.
- Transfer state machine.
- Bounded concurrency.
- Persistent queue.
- Retry handling.
- Part reconciliation.

Acceptance:

Interrupted uploads can resume
without unnecessarily retransmitting
successfully committed parts.

## PHASE 7 — Background Transfer

Objectives:

- Background URLSession.
- File-backed upload tasks.
- Lifecycle handling.
- Transfer task restoration.
- App relaunch reconciliation.

Acceptance:

The application correctly manages
supported background transfer behavior.

Document OS limitations.

## PHASE 8 — Integrity and Verification

Objectives:

- File hashing.
- Server verification.
- Invalid-file rejection.
- Multipart finalization safety.
- Stale upload cleanup.

Acceptance:

Only verified files become deliverable.

## PHASE 9 — Client Portal and Delivery

Objectives:

- Client preview portal.
- Invoice display.
- Sandbox payment flow.
- Secure download authorization.
- Delivery state machine.

Acceptance:

Only eligible projects provide
authorized final media downloads.

## PHASE 10 — Offline and Recovery

Objectives:

- Offline project drafts.
- Durable pending operations.
- Transfer restoration.
- Server reconciliation.
- Conflict handling.

Acceptance:

Network failure does not corrupt
local or authoritative state.

## PHASE 11 — Testing and Optimization

Objectives:

- Unit tests.
- Integration tests.
- Concurrency tests.
- Failure injection.
- UI tests.
- Physical-device testing.
- Performance profiling.

Acceptance:

Critical scenarios are tested.

Measured performance is documented.

## PHASE 12 — Portfolio Preparation

Objectives:

- Final README.
- Architecture diagrams.
- Transaction flow documentation.
- Transfer engine documentation.
- Test reports.
- Performance analysis.
- Demonstration script.
- Portfolio case study.

Acceptance:

An experienced engineer can understand,
run, test, and evaluate the project.

---

# 43. DOCUMENTATION REQUIREMENTS

Create meaningful documentation.

## README.md

Include:

- Product overview.
- Screenshots.
- Key features.
- Technology stack.
- Architecture overview.
- Installation.
- Environment configuration.
- Database setup.
- Object storage setup.
- Sandbox payment setup.
- Running the iOS application.
- Running the client portal.
- Testing.
- Known limitations.

## ARCHITECTURE.md

Explain:

- System architecture.
- Component boundaries.
- Data flow.
- Repository structure.
- Local/server authority.
- Concurrency decisions.

## TRANSACTION_ENGINE.md

Explain:

- Invoice state machine.
- Payment state machine.
- Idempotency.
- Transaction boundaries.
- Database consistency.
- Webhook processing.
- Reconciliation.

## TRANSFER_ENGINE.md

Explain:

- Transfer state machine.
- Multipart upload.
- Background URLSession.
- Retry mechanism.
- Transfer recovery.
- Integrity verification.
- Storage cleanup.
- iOS lifecycle limitations.

## DELIVERY_SECURITY.md

Explain:

- Authorization rules.
- Payment-dependent delivery.
- Media verification requirements.
- Signed URLs.
- Access revocation.

## TESTING.md

Explain:

- Test strategy.
- Test scenarios.
- Tests executed.
- Actual results.
- Remaining limitations.

## PERFORMANCE.md

Explain:

- Test device.
- Test file sizes.
- Memory observations.
- CPU observations.
- Upload behavior.
- Optimizations performed.

Do not invent test results.

---

# 44. PORTFOLIO CASE STUDY

Create a professional engineering case study.

Suggested title:

"Slate — Engineering Reliable Media Delivery
and Transaction Processing on iOS"

Include:

## Problem

Professional media delivery requires
reliable transfers and accurate commercial workflows.

## Solution

A native iOS application combining
resumable media transfer,
transaction processing,
and secure delivery.

## Technical Challenges

Discuss:

- Background transfer limitations.
- Large file memory management.
- Upload state persistence.
- Payment event duplication.
- Transaction concurrency.
- Distributed consistency.
- Secure delivery authorization.

## Architecture

Present clear architecture diagrams.

## Engineering Decisions

Explain why specific technologies
and architectural patterns were selected.

Include meaningful tradeoffs.

## Verification

Present actual tests
and performance measurements.

## Outcome

Describe what was implemented.

Avoid exaggerated claims.

---

# 45. DEMONSTRATION REQUIREMENTS

Prepare a professional demonstration scenario.

The demo should communicate
both product functionality
and engineering capability.

## Demo Part 1 — Project Workflow

Create a project.

Generate an invoice.

Import media files.

## Demo Part 2 — Reliable Upload

Start uploading a large file.

Interrupt network connectivity.

Show the transfer entering
a recoverable state.

Restore connectivity.

Demonstrate resumed transfer.

Show successful integrity verification.

## Demo Part 3 — Transaction Integrity

Open the client portal.

Complete a sandbox payment.

Show the authoritative invoice update.

Replay a duplicate webhook
through the development test harness.

Show that the payment
is not applied twice.

## Demo Part 4 — Delivery Authorization

Before verified payment:

Final download is unavailable.

After verified payment and verified media:

Final download becomes available.

## Demo Part 5 — Engineering Evidence

Show:

- Architecture diagram.
- Transaction tests.
- Transfer recovery tests.
- Actual performance measurements.

The demo must not misrepresent
simulated behavior as real production behavior.

---

# 46. ACCEPTANCE CRITERIA

The MVP is complete when:

## Native iOS

[ ] Application builds successfully.

[ ] UIKit is the primary UI framework.

[ ] Authentication works.

[ ] Project navigation works.

[ ] Media import works.

[ ] Local persistence works.

[ ] Transfer queue persists across relaunch.

[ ] Background URLSession is integrated.

[ ] Transfer state is recoverable.

[ ] Media processing does not block the UI unnecessarily.

[ ] Secure token storage is implemented.

[ ] Important errors are handled.

## Transaction Engine

[ ] Invoice creation is functional.

[ ] Invoice state transitions are validated.

[ ] Monetary calculations are integer-based.

[ ] Payment sandbox is integrated.

[ ] Webhook signatures are verified.

[ ] Duplicate events are handled.

[ ] Idempotency is enforced.

[ ] Concurrent updates are protected.

[ ] Payment history is auditable.

[ ] Payment state is server-authoritative.

## Transfer Engine

[ ] Multipart upload works.

[ ] Interrupted transfers are recoverable.

[ ] Successful parts are not unnecessarily retransmitted.

[ ] Upload concurrency is bounded.

[ ] Expired upload URLs are handled.

[ ] File integrity is verified.

[ ] Failed verification blocks delivery.

[ ] Abandoned uploads can be cleaned up.

## Delivery

[ ] Client preview works.

[ ] Final assets remain private.

[ ] Payment requirements are enforced.

[ ] Media verification requirements are enforced.

[ ] Unauthorized downloads are rejected.

[ ] Delivery access can be revoked.

## Quality

[ ] Important unit tests pass.

[ ] Backend integration tests pass.

[ ] Concurrency behavior is tested.

[ ] Failure scenarios are tested.

[ ] Documentation is complete.

[ ] Known limitations are documented.

[ ] Physical-device results are distinguished
    from simulator results.

Do not mark unverified criteria as complete.

---

# 47. STRICT ENGINEERING CONSTRAINTS

## Constraint 1 — Native iOS First

The project is primarily an iOS engineering portfolio.

Backend features exist to support
meaningful native application behavior.

Do not spend disproportionate effort
building web administration features.

## Constraint 2 — No Fake Reliability

Do not simulate resumable uploads
by merely resetting a progress bar.

Implement actual resumable transfer behavior.

## Constraint 3 — No Fake Financial Correctness

Do not mark payments successful
from client-side actions.

Use verified provider information.

## Constraint 4 — No Client-Side Authorization

Never rely on iOS UI state
to protect final media files.

## Constraint 5 — No Unbounded Concurrency

Do not launch unlimited uploads simultaneously.

## Constraint 6 — No Uncontrolled Memory Usage

Do not read large media files
into memory unnecessarily.

## Constraint 7 — No Unnecessary Infrastructure

Avoid microservices, Kafka,
Kubernetes, and other infrastructure
without concrete requirements.

## Constraint 8 — No Silent Data Corruption

Preserve important state
and reject inconsistent updates.

## Constraint 9 — No Fabricated Verification

Do not claim a successful build,
test, or performance result
without actually verifying it.

## Constraint 10 — No Dead UI

Every visible primary action
must have meaningful working behavior.

---

# 48. FINAL ENGINEERING REVIEW

Before considering the project complete,
perform a structured audit.

## Native iOS Review

- UIKit lifecycle.
- Concurrency isolation.
- Task ownership.
- Memory leaks.
- Main-thread blocking.
- Transfer restoration.
- Authentication state.
- Local persistence.

## Transaction Review

- Monetary correctness.
- Idempotency.
- Database constraints.
- Webhook validation.
- Concurrent updates.
- Audit trail.
- Reconciliation.

## Transfer Review

- Multipart correctness.
- Retry behavior.
- Background lifecycle.
- File integrity.
- State restoration.
- Storage cleanup.
- Duplicate completion protection.

## Security Review

- Authentication.
- Authorization.
- Keychain usage.
- Signed URL exposure.
- Private object storage.
- Webhook signatures.
- Sensitive logging.

## UX Review

- Navigation.
- Feedback.
- Error handling.
- Transfer state clarity.
- Payment state clarity.
- Accessibility.
- Responsive layouts.

## Test Review

- Unit test coverage.
- Integration behavior.
- Failure recovery.
- Concurrency correctness.
- Physical-device validation.

Fix material correctness,
reliability, and security issues.

Avoid endlessly expanding the scope.

---

# 49. EXPECTED FINAL DELIVERABLES

The final repository should contain:

1. Native Swift/UIKit iOS application.
2. Functional REST API.
3. PostgreSQL database schema and migrations.
4. S3-compatible media transfer integration.
5. Sandbox payment integration.
6. Lightweight client web portal.
7. Functional transaction state machines.
8. Functional transfer state machines.
9. Secure delivery authorization.
10. Automated tests.
11. Architecture documentation.
12. Transaction and transfer technical documentation.
13. Reproducible demo instructions.
14. Professional engineering case study.

Optional:

- Demo video.
- Xcode Instruments results.
- Failure injection demonstration.
- Architecture diagrams.
- Performance comparisons.

---

# 50. EXECUTION INSTRUCTIONS

Begin by inspecting the repository
and available development environment.

Identify existing files and dependencies
before creating or modifying the project.

Then proceed incrementally.

Do not stop after producing an architecture proposal.

Implement the application.

Prioritize the native iOS foundation.

Develop the transaction and transfer engines
as independently testable components.

Integrate them through explicit project
and delivery authorization rules.

Use real APIs and real persistence.

Use development and sandbox environments
for financial operations.

Test important failure scenarios.

Document actual results.

Exercise independent engineering judgment
when requirements leave implementation details open.

Prefer a smaller, verified implementation
over a larger incomplete system.

Do not introduce artificial complexity
for the sake of technical sophistication.

The final project must clearly demonstrate:

1. Professional Swift and UIKit engineering.
2. Reliable asynchronous processing.
3. Persistent and recoverable media transfers.
4. Correct financial transaction state management.
5. Safe coordination of distributed systems.
6. Secure media delivery.
7. Strong automated testing.
8. Practical performance optimization.

The final objective is:

Build Slate as a polished, technically credible,
native iOS application that demonstrates
advanced software engineering through
reliable large-file transfer,
transaction integrity,
offline persistence,
concurrency management,
and secure commercial media delivery.

The final result should be suitable
for technical evaluation by experienced
mobile and backend engineers.