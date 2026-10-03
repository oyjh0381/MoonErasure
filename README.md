# MoonErasure

MoonErasure is a MoonBit library for systematic Reed–Solomon erasure coding over GF(256). It turns `k` data shards into `k + m` shards and reconstructs a stripe from **any `k` intact shards**. The first `k` shards retain the original padded data. Applications decide where to store, send, authenticate and persist the shards.

The library supports complete objects, bounded stripes, independent checksum-protected frames, repair plans, range reads, incremental encoding and decoding, a portable single-file bundle format, and health inspection. The code is original MoonBit and runs on `wasm`, `wasm-gc`, `js` and `native` targets.

## Why this project

MoonBit applications that distribute backups or packets need a reusable redundancy layer. A backup can tolerate loss of any `m` independent shards per stripe without retaining `m` complete replicas. An edge transfer can tolerate lost packets; a storage scrubber can identify damaged frames and regenerate only missing slots. [Topic research](docs/SELECTION_RESEARCH.md) explains the nearest mooncakes.io project found and the distinct contribution. Search results are time dependent and must be repeated before release.

## Install and run

Install the [MoonBit toolchain](https://docs.moonbitlang.com/en/latest/toolchain/), then add the published library:

```sh
moon add oyjh0381/moonerasure@0.1.0
```

Import the library in your application's `moon.pkg`:

```moonbit
import {
  "oyjh0381/moonerasure",
}
```

Source: [oyjh0381/MoonErasure](https://github.com/oyjh0381/MoonErasure).
Package: [oyjh0381/moonerasure](https://mooncakes.io/docs/oyjh0381/moonerasure).
Maintainer: `oyjh0381`.

From the source repository, run:

```sh
moon check --target all --deny-warn
moon build --target all --deny-warn
moon test --target all --deny-warn
moon run cmd/main --target wasm-gc
```

The Mooncakes module name is `oyjh0381/moonerasure`. No third-party runtime packages are required. Release and verification evidence is recorded in [the 0.1.0 release record](docs/RELEASE_0.1.0.md).

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

For long-lived storage inventories, `FrameCatalog::add_bytes` validates CRC before admission, `invalidate` removes a suspect slot, and `recover_range` reads only relevant indexed stripes. See [October features](docs/OCTOBER_FEATURES.md).

## Runnable scenarios

| Command | Demonstrated need |
| --- | --- |
| `moon run cmd/main` | Backup recovery and replacement frame generation after two placements disappear. |
| `moon run examples/transfer` | Out-of-order packets, one absent data packet and one checksum-failed parity packet per stripe. |
| `moon run examples/scrub` | Frame inventory, health inspection, and persisted-slot repair. |
| `moon run examples/range` | Recover a byte range by fetching only overlapping stripes. |
| `moon run examples/stream` | Encode arbitrary input chunks and decode one stripe at a time. |
| `moon run examples/maintenance` | Admit a frame batch atomically and plan reads over currently recoverable byte ranges. |
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

## 十月第二轮：批量事务与可恢复区间

`FrameCatalog::add_many(frames, max_frames?)` 在分离槽表上验证所有已解析帧，成功才提交；外部帧字节须先经 CRC 解析，批量操作不提供跨线程或持久化事务。`recoverable_ranges(max_ranges?)` 返回分片数量足够的最大连续半开字节区间，不解码整对象，也不认证分片内容。范围读取的参数是起点和长度：`recover_range(range.start(), range.length())`。

运行 `moon run examples/maintenance --target wasm-gc`，展示两段可恢复数据与中间缺失条带。详见 [本轮审查与复杂度](docs/SECOND_REVIEW.md) 和 [十月申报资料稿](十月项目申报书.md)。
