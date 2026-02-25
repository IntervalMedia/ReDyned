# Tests/Fixtures

This folder contains placeholder fixtures and instructions for Phase-1 of the Roadmap rollout (Class Dump & Type Reconstruction).

Purpose:
- Provide deterministic placeholder files so CI and local tests can validate scaffolding.

Files:
- `sample_arm64.placeholder` — placeholder binary for an arm64 sample (zero-byte by default).
- `sample_objc.placeholder` — placeholder binary for an ObjC sample (zero-byte by default).

Usage:
- Phase-1 tests validate that these fixtures are present. Replace placeholders with real sample binaries in later phases.

Do not commit large binaries to the repo; if you must add real samples, store them in an LFS-enabled repo or an external artifacts store and update tests to download them during CI.
