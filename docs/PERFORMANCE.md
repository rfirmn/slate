# Performance notes

**Device:** iPhone 17 Pro Simulator, iOS 26.0.1 (Xcode 26.0.1) for current UI/unit verification. This is a Simulator result, not physical hardware.

**Transfer fixture:** 17 MiB PDF; 8 MiB multipart part size. The latest live integration test completed in 2.58 seconds on the iPhone 17 Pro Simulator. It sends one real 8 MiB MinIO part, restores a stale journal with zero local confirmed bytes, reconciles ListParts, resumes the remaining part in file-backed background URLSession, verifies whole-object SHA-256 server-side, and removes the staged source after success. The 2.58-second test duration includes local setup/assertions and is not an upload throughput benchmark.

Media SHA-256 and part-file creation stream in 1 MiB blocks. URLSession uploads files by path, avoiding a whole-video in-memory `Data` value. The transfer actor caps all concurrent queue parts at two. Gallery previews load only in visible reusable cells and cancel when cells leave view. Core Data transfers immutable Codable values across actor boundaries and keeps managed objects on one private context.

No Instruments capture, physical-device memory/CPU/thermal measurement, network-throughput benchmark, or battery test has been performed. No production performance claim is made. The first MinIO Compose build downloads and compiles the pinned Go source dependency tree, which adds one-time development setup time rather than application runtime cost.
