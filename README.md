# MoonErasure

MoonErasure is a MoonBit library for systematic Reed–Solomon erasure coding over GF(256). It turns `k` data shards into `k + m` shards and reconstructs a stripe from **any `k` intact shards**. The first `k` shards retain the original padded data. Applications decide where to store, send, authenticate and persist the shards.

The library supports complete objects, bounded stripes, independent checksum-protected frames, repair plans, range reads, incremental encoding and decoding, a portable single-file bundle format, and health inspection. The code is original MoonBit and runs on `wasm`, `wasm-gc`, `js` and `native` targets.

## Why this project

MoonBit applications that distribute backups or packets need a reusable redundancy layer. A backup can tolerate loss of any `m` independent shards per stripe without retaining `m` complete replicas. An edge transfer can tolerate lost packets; a storage scrubber can identify damaged frames and regenerate only missing slots. [Topic research](docs/SELECTION_RESEARCH.md) explains the nearest mooncakes.io project found and the distinct contribution. Search results are time dependent and must be repeated before release.

## Install and run

Install the [MoonBit toolchain](https://docs.moonbitlang.com/en/latest/toolchain/), then from this repository:

```sh
moon check --target all --deny-warn
moon build --target all --deny-warn
moon test --target all --deny-warn
moon run cmd/main --target wasm-gc
```

The intended mooncakes module name is `oyjh0381/moonerasure`. Until publication, use this repository as a local MoonBit module dependency. No third-party runtime packages are required. The `moon.mod` repository URL is the planned public location; it is not a claim that a remote exists yet.

## Minimal library use

```moonbit
let codec = try! @moonerasure.Codec::new(3, 2)
let object = try! @moonerasure.encode_object(
  codec,
  b"backup bytes",
  123,
  stripe_payload_limit=64,
)
let retained : Array[@moonerasure.ShardEnvelope] = []
for frame in object.frames() {
  if frame.shard_index() != 1 && frame.shard_index() != 4 {
    retained.push(frame)
  }
}
let recovered = try! @moonerasure.recover_object(object.manifest(), retained)
assert_eq(recovered.payload(), b"backup bytes")
let replacements = try! @moonerasure.repair_object(object.manifest(), retained)
```

The example drops two shards per stripe and reconstructs them from the remaining three. In production, store each frame's `to_bytes()` independently and store the 32-byte manifest separately with appropriate durability. Parse received bytes with `ShardEnvelope::from_bytes`; alternatively `recover_serialized_object` treats malformed or CRC-failed frames as known erasures and returns issue positions. Do not trust the shard index inside a damaged frame.

## Runnable scenarios

| Command | Demonstrated need |
| --- | --- |
| `moon run cmd/main` | Backup recovery and replacement frame generation after two placements disappear. |
| `moon run examples/transfer` | Out-of-order packets, one absent data packet and one checksum-failed parity packet per stripe. |
| `moon run examples/scrub` | Frame inventory, health inspection, and persisted-slot repair. |
| `moon run examples/range` | Recover a byte range by fetching only overlapping stripes. |
| `moon run examples/stream` | Encode arbitrary input chunks and decode one stripe at a time. |
| `moon run examples/benchmark --target native` | Verified fixed workload for local timing of repeated loss patterns. |

All examples exit with a failing assertion if the round trip is wrong. [API guide](docs/API.md) explains each public workflow; [wire format](docs/WIRE_FORMAT.md) records byte layouts and compatibility rules.
See [performance notes](docs/PERFORMANCE.md) for complexity and reproducible timing guidance.

## Capacity and failure boundary

- `1 <= k,m <= 255`, `k + m <= 256`; default encoded-byte budget is 16 MiB per stripe. The current implementation builds a dense generator matrix, so modest `k` and `m` are recommended in practice.
- Default maximum object size is 64 MiB, default stripe payload limit 64 KiB, and maximum stripe count 4096. Callers can lower budgets; all public allocations are bounded. The in-memory complete-object API has a default 128 MiB encoded-output budget; the incremental encoder limits internal buffering to one stripe but returned frames can still fill memory if a caller holds them.
- Recovery succeeds for **erasures**, where the failed shard is identified or rejected by CRC. More than `m` lost or rejected shards in one stripe is unrecoverable. CRC-32C is for accidental damage only; it is not encryption, authentication, a MAC, or a defense against maliciously crafted frames.
- With exactly `k` surviving frames, Reed–Solomon parity provides no spare evidence to locate an unknown corrupted byte. Validate frame checksums and use authenticated storage or a cryptographic object digest when adversarial integrity matters.
- Each object's manifest must be preserved. The library does not choose storage nodes, guarantee independent failure domains, transfer packets, perform I/O, or provide durable transactions.

## Verification

The repository includes black-box and white-box tests for GF arithmetic, matrix inversion, known vectors, exhaustive small erasure combinations, envelopes, bounds, corrupted bytes, multi-stripe objects, bundle parsing, incremental chunk boundaries, range reads, repair and health. CI checks/builds/tests all four backends, runs every example, and checks formatting and public interfaces. See [testing notes](docs/TESTING.md).

## Design and license

See [architecture](docs/ARCHITECTURE.md), [domain glossary](CONTEXT.md), [decision record](docs/adr/0001-systematic-gf256-shards.md), [selection research](docs/SELECTION_RESEARCH.md), [local review](docs/LOCAL_REVIEW.md) and [third-party notice](THIRD_PARTY_NOTICES.md). Licensed under [Apache-2.0](LICENSE). No external source code or test corpus was copied into this repository.
