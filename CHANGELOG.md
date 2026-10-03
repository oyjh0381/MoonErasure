# Changelog

## 0.1.0 — 2026-10-03

- Implemented systematic GF(256) Reed–Solomon coding with any-`k` erasure recovery, parity verification, repair planning and a bounded matrix cache for repeated loss patterns.
- Added versioned CRC-32C frames, object manifests and a strict bundle archive format with incremental parsing.
- Added bounded multi-stripe object encode/recover/repair, incremental stripe workflows, partial reads, health inspection, frame inventory and raw-frame diagnostics.
- Added deterministic known-vector, combination, mutation, resource-boundary, large-workload and four-backend tests; runnable backup, transfer, scrub, range, streaming and timing examples.
- Added architecture, API, wire-format, testing, performance, source-provenance and topic-selection documentation, plus CI and Apache-2.0 license.

Initial public release as `oyjh0381/moonerasure@0.1.0`. CRC-32C detects
accidental corruption; it is not cryptographic authentication. Storage,
transport, placement and durable transactions remain host responsibilities.

## 2026-10-03 — October maintenance additions

- Add atomic catalog batch admission and maximal recoverable byte ranges.
- Add regression tests, executable integration examples, source archives and October proposal fact drafts.
