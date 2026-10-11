# Slate shared implementation contract

Base URL http://localhost:3000 (iOS simulator). Portal http://localhost:3001.
JSON is camelCase; IDs UUID strings; dates ISO8601 strings. Money integer IDR rupiah (zero decimal), `currency: IDR`. HTTP errors `{error: string}`. No wrappers unless below. Auth `Authorization: Bearer <token>`. Mutations use `Idempotency-Key` UUID. Every owner route enforces ownership.

## Creator
- POST /auth/register {email,password,displayName} -> {token,user:{id,email,displayName}}
- POST /auth/login {email,password} -> same
- POST /auth/logout -> {ok:true}, revokes token
- GET /auth/me -> user
- GET /clients -> array of {id,name,email,phone?}
- POST /clients {name,email,phone?} -> client
- GET /projects -> Project[]
- POST /projects {title,description,clientId,deliverables:[{title,type,expectedQuantity}]} -> Project
- GET /projects/:id -> Project
- PATCH /projects/:id {status,version} -> Project; validated transitions
- POST /projects/:id/invoices {items:[{description,quantity,unitPriceMinor}],dueAt?} -> Invoice DRAFT
- POST /invoices/:id/issue {} -> Invoice
- POST /invoices/:id/void {} -> Invoice
- POST /invoices/:id/reconcile {} -> Invoice (query provider)
- POST /projects/:id/share {} -> {token,url} portal bearer capability
- POST /projects/:id/delivery/release {} -> {status}
- POST /projects/:id/delivery/revoke {} -> {status}

Project = {id,title,description,status,currency,version,createdAt,client:{id,name,email,phone?},deliverables:[{id,title,type,expectedQuantity}],invoice:Invoice?,media:Media[],deliveryStatus:string,activity:[{id,action,createdAt}]}. List may contain same full shape. Project states DRAFT CONFIRMED IN_PROGRESS READY_FOR_DELIVERY DELIVERED COMPLETED CANCELLED.
Invoice = {id,invoiceNumber,status,totalMinor,currency,dueAt?,paidAt?,items:[{id,description,quantity,unitPriceMinor,lineTotalMinor}],payments:[{id,status,provider,createdAt,amountMinor}]}. Invoice states DRAFT ISSUED PAID VOID.
Media = {id,filename,mimeType,sizeBytes,status,contentHash,verifiedAt?,previewURL?}. No original preview for unpaid client. Media states UPLOADING VERIFIED INVALID.

## Transfers (authenticated)
- POST /transfers {projectId,filename,mimeType,sizeBytes,contentHash} -> TransferSession
- GET /transfers/:id -> TransferSession; reconcile storage ListParts
- POST /transfers/:id/parts/:number/sign {} -> {url}
- POST /transfers/:id/complete {} -> {mediaAsset:Media}; server uses storage parts, streams SHA256; repeat safe
- POST /transfers/:id/cancel {} -> {ok:true}
TransferSession = {id,mediaAssetId,status,totalBytes,partSize,parts:[{partNumber,sizeBytes,storageETag}],expiresAt}. Part size 8 MiB. PUT signed URL file-backed then reconcile. Completed state COMPLETED. Server can complete storage and verify repeatedly after crash. iOS idempotency key saved per logical operation.

## Portal (capability token, no creator auth)
- GET /portal/:token -> {project:Project,deliveryStatus,developmentPayments:boolean}
- POST /portal/:token/checkout {} -> {redirectURL,attemptId}; idempotency required
- GET /portal/:token/media/:id/download -> {url}; final delivery checks paid, all quantities verified, explicit released and not revoked; short-lived signed URL
- POST /dev/payments/:attemptId/settle (development only, requires DEV_PAYMENT_SECRET via X-Dev-Secret; invoked server-to-server by Next dev route) -> {ok:true}; signed simulated provider event, same transactional handler
- POST /webhooks/midtrans -> authenticated provider signature, amount checked, event deduped

The portal must never receive creator tokens or dev secrets. /portal GET strips private keys/payment references, allows thumbnails only. Share token must be high entropy and hashed at rest. No production dev controls.
