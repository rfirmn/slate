# Local infrastructure

Compose runs PostgreSQL 16 at localhost:55432 and source-built MinIO at localhost:9000 (console9001). Volumes are persistent; `docker compose down` retains them. Do not use `down -v` unless you intend to delete local databases and objects.

```sh
docker compose -f infrastructure/docker-compose.yml up -d --build
docker compose -f infrastructure/docker-compose.yml ps
```

The MinIO Dockerfile builds the official pinned source tag `RELEASE.2025-10-15T17-29-55Z`. Published official MinIO Community images and binaries have been withdrawn. MinIO's [official source repository](https://github.com/minio/minio) documents source compilation. Its AGPL license remains applicable; this local development source build is not a recommendation to run an unmaintained community release publicly. Deploy with a maintained private S3-compatible service.

The first source build fetches a substantial Go dependency tree. A native source-build fallback was used during development on Apple Silicon while the Docker build was being verified:

```sh
mkdir -p /tmp/slate-tools
GOBIN=/tmp/slate-tools go install github.com/minio/minio@RELEASE.2025-10-15T17-29-55Z
MINIO_ROOT_USER=slate_minio MINIO_ROOT_PASSWORD=slate_minio_dev_password \
  /tmp/slate-tools/minio server /tmp/slate-minio-data --address :9000 --console-address :9001
```

Run either native MinIO or the Compose MinIO container on these ports, not both. Native fallback stores bytes under `/tmp`; use a durable directory for longer-lived development. The API creates its private bucket on demand, then all uploads and reads use scoped signed URLs. No bucket-wide public read policy is installed.

Stale transfers and orphaned multipart uploads are cleaned by `npm run maintenance` in `services/api`. This command handles S3/MinIO directly; it does not rely on an unsupported MinIO AbortIncompleteMultipartUpload lifecycle XML configuration. Schedule maintenance periodically when deploying the API.

For a real device, set S3_ENDPOINT and PORTAL_URL to reachable LAN/HTTPS URLs before starting API; a presigned upload URL's host is part of its signature and cannot be rewritten afterward. Local credentials in `.env.example` are only for local development.
