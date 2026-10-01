# Architecture and algorithm

MoonErasure's layers are intentionally separate:

1. `field.mbt` implements GF(2^8) arithmetic with polynomial `0x11d` and exp/log tables.
2. `matrix.mbt` constructs a Vandermonde matrix, normalizes the top `k` rows to identity, and inverts selected rows by Gauss–Jordan elimination.
3. `codec.mbt` implements systematic encoding, parity verification and erasure reconstruction. `repair_plan.mbt` identifies selected inputs and missing slots.
4. `envelope.mbt` and `crc32c.mbt` define independently verifiable frames. CRC failure converts accidental corruption into a known erasure.
5. `stripe.mbt` maps an arbitrary byte slice to fixed-length shards and back, checking canonical zero padding.
6. `manifest.mbt`, `object.mbt`, incremental encoder/decoder, catalog, scan, repair, range and health modules build an application-neutral object layer.
7. `bundle.mbt` and `bundle_stream.mbt` provide a strict archive transport; frames can also be stored separately.

The generator is `G = V × inverse(V_top)`, where `V` is a `(k + m) × k` Vandermonde matrix over distinct field elements and `V_top` is its first `k` rows. Thus the first `k` rows of `G` are identity and any `k` rows are invertible. Encoding costs `O(m k L)` field operations for shard length `L`; generator construction costs `O(k^3 + (k + m)k^2)` with dense matrices. Recovery inverts a `k × k` selected-row matrix, `O(k^3)`, then reconstructs missing data and parity with cost up to `O(k^2 L + m k L)`. Data-only availability skips matrix inversion. The current implementation favors straightforward portable arithmetic over SIMD or backend-specific intrinsics.

`RecoverySession` can cache a bounded number of inverses keyed by the first `k` available shard indices. Reusing a pattern removes the `O(k^3)` inversion on subsequent stripes, while decoding and validation still depend on shard length. The default capacity is 16 patterns, maximum 64; FIFO replacement keeps memory predictable. A session stores matrices only, never payload bytes. Its mutable counters and cache are local to that session.

Object encoding splits at a configurable stripe payload limit; each stripe can lose any `m` shards independently. A final stripe is padded with zeros only in data shards; its original byte count is recorded in every frame and checked against the manifest. This prevents a consumer from confusing padding with file content. The format is deterministic for fixed input, `k`, `m`, set id and stripe limit.

The object API is in-memory and bounded. Incremental encoding and decoding support adapters that stream to storage, but the caller owns I/O and buffering. No globals, shared mutable cache, background tasks or platform-specific file APIs are used. Per-call codec and stream objects hold their own state. The library does not promise thread-safe mutation of the same object instance; use separate instances per concurrent operation.

Known corruption and adversarial tampering are different. CRC-32C catches many accidental changes and makes a bad frame discardable, but an attacker can recalculate CRC. Use a cryptographic hash or authenticated transport outside this library. If only exactly `k` frames survive, the code cannot tell which of those has an unknown incorrect byte. When more than `k` frames survive, the implementation checks that the reconstructed codeword matches all supplied frames, but a mismatch identifies inconsistency, not necessarily the malicious frame.

The design choice and ecosystem rationale are recorded in [ADR 0001](adr/0001-systematic-gf256-shards.md) and [selection research](SELECTION_RESEARCH.md).
