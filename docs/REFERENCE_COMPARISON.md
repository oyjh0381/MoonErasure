# Functional scope against klauspost/reedsolomon

Reference: [`klauspost/reedsolomon` v1.14.2](https://github.com/klauspost/reedsolomon/tree/v1.14.2), MIT license. See its [Encoder interface](https://pkg.go.dev/github.com/klauspost/reedsolomon@v1.14.2#Encoder) and [README](https://github.com/klauspost/reedsolomon/blob/v1.14.2/README.md). The table describes behavior, not source translation or a performance ranking.

| Capability | Go reference | MoonErasure 0.2.0 |
| --- | --- | --- |
| Systematic GF(256), parity verification | `New`, `Encode`, `Verify` | `Codec::new`, `encode`, `verify` |
| Known-erasure reconstruction | `Reconstruct` | `reconstruct`; additionally checks surplus input consistency |
| Only requested data/parity | `ReconstructSome` | `reconstruct_selected`; detached outputs in requested order |
| Small data replacements | `Update` | `update_parity`; explicit old/new indexed pairs, no input mutation |
| Data-only reconstruction | `ReconstructData` | Request all data indices with `reconstruct_selected` |
| Streams | `NewStream`, readers/writers | Bounded object encoder/decoder; host owns actual I/O |
| Repeated erasure-pattern matrices | Inversion cache | Bounded `RecoverySession` cache for full reconstruction |
| Packet/object integrity and inventories | Application-defined | CRC frames, manifests, catalog, range reads and repair |
| Progressive parity/decode contributions | `EncodeIdx`, `DecodeIdx` | Not implemented; object chunking is a different operation |
| SIMD, goroutines, GF(65536), matrix variants | Available modes/options | Not implemented; serial portable GF(256) only |
| Dimensions | Includes zero parity and larger-field modes | `1 <= k,m <= 255`, total `<=256`, configured byte limits |

CRC protects accidental damage, not malicious input. Both libraries require callers to identify failed shards; neither promises to repair unknown arbitrary corruption from only `k` inputs. MoonErasure does not implement reference CPU optimizations or claim matching throughput. Its object wire format is independent and is not the Go library's file format.

## Reproducible behavioral agreement

`tools/reference/go.mod` pins v1.14.2. The original helper invokes `Encode`, `ReconstructSome`, `Update` and `Verify` on deterministic bytes using default Vandermonde GF(256) and `WithLeopardGF(false)`. It emits 28 configurations: `1+1`, `2+2`, `3+2`, `4+1`, `6+3`, `10+4`, `16+8`, each with 1, 3, 17 and 64 bytes per shard. These cover a single-parity case, multiple erasures, reversed requested output order, and one/two changed data shards.

From `tools/reference`, run:

```sh
go run . > ../../testdata/reedsolomon-v1.14.2.json
```

From the project root, run:

```sh
python tools/generate_reference_tests.py
moon fmt
moon test --target all --deny-warn
git diff --exit-code
```

The committed generated tests compare all encoded bytes, complete recovery, requested output and delta-updated parity. They are excluded from handwritten source counts. Vector agreement covers this pinned configuration subset; Cauchy, PAR1, Jerasure, custom matrices and Leopard modes are outside the compatibility claim. Wire-envelope compatibility is not implied.
