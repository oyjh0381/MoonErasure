# MoonErasure

**MoonBit 原生 Reed–Solomon 编码、选择性重建与增量更新库。**

本库面向备份工具、对象存储适配器、块数据更新与分片传输服务，输入是等长数据片、已知丢失位置和更新前后字节，输出是校验片、指定重建片或更新后的校验片。核心计算不依赖 Go/JavaScript 运行时，支持 Native、JS、Wasm 和 Wasm-GC。

功能范围以 [`klauspost/reedsolomon` v1.14.2 对照表](docs/REFERENCE_COMPARISON.md)说明；[三个可执行验证场景](docs/SCENARIOS.md)给出输入、断言及成本模型。参考库提供成熟算法功能基准，本库的实现、帧和对象格式独立编写。

MoonErasure is a MoonBit library for systematic Reed–Solomon erasure coding over GF(256). It turns `k` data shards into `k + m` shards and reconstructs a stripe from **any `k` intact shards**. The first `k` shards retain the original padded data. Applications decide where to store, send, authenticate and persist the shards.

The library supports complete objects, bounded stripes, independent checksum-protected frames, repair plans, range reads, incremental encoding and decoding, a portable single-file bundle format, and health inspection. The code is original MoonBit and runs on `wasm`, `wasm-gc`, `js` and `native` targets.

## Why this project

MoonBit applications that distribute backups or packets need a reusable redundancy layer. A backup can tolerate loss of any `m` independent shards per stripe without retaining `m` complete replicas. An edge transfer can tolerate lost packets; a storage scrubber can identify damaged frames and regenerate only missing slots. The codec exposes multi-shard recovery, bounded object assembly and repair planning as reusable byte operations.

## Install and run

Install the [MoonBit toolchain](https://docs.moonbitlang.com/en/latest/toolchain/), then add the published library:

```sh
moon add oyjh0381/moonerasure@0.2.0
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

The Mooncakes module name is `oyjh0381/moonerasure`. No third-party runtime packages are required. Development uses MoonBit compiler v0.10.16 or later. Version 0.1.0 does not include the selective-recovery or delta-update methods added in 0.2.0.

## Core operations and explicit inputs

| Operation | Input | Output / contract |
| --- | --- | --- |
| `Codec::encode` / `encode_all` | `k` equal nonempty data shards | `m` parity shards / detached complete codeword |
| `Codec::verify` | All `k+m` shards | Whether parity agrees with data; no corruption localization |
| `Codec::reconstruct` | `k+m` optional slots, at least `k` known-intact | Complete codeword; surplus supplied shards cross-checked |
| `Codec::reconstruct_selected` | Optional slots plus unique requested indices | Only requested data/parity, in request order; surplus cross-checked |
| `Codec::update_parity` | Old parity and indexed old/new data pairs | Detached new parity; unchanged data shards are not supplied |
| Object / catalog methods | Manifest and validated frames | Stripe/range recovery, repair frames, health and inventory |

```moonbit
// Missing slots remain None; only shard 1 is materialized in the result.
let selected = try! codec.reconstruct_selected(surviving, [1])
// Both old data and parity must belong to the same consistent generation.
let changes : Array[@moonerasure.DataShardUpdate] = [
  { index: 3, old_data: old_block, new_data: new_block },
]
let next_parity = try! codec.update_parity(old_parity, changes)
```

For executable definitions of these variables and assertions, run the examples below. Persist new data and returned parity as one generation in the host storage adapter; this library does not provide durable commit semantics. An empty selected request only validates input shapes, returns `[]`, and performs no codeword consistency check. A nonempty request requires at least `k` known-intact inputs, even when its requested shard is already present.

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
| `moon run examples/degraded_read` | Read one missing 4 KiB data block from a 6+3 stripe without allocating unrelated missing shards. |
| `moon run examples/incremental_update` | Update one 4 KiB block in a 10+4 stripe, compare parity with full encoding, then tolerate four erasures. |
| `moon run examples/selective_repair` | Rebuild and replace only three failed backup placements, then verify the complete codeword. |
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

Pinned Go reference vectors cover encoding, full reconstruction, requested reconstruction and parity updates under the same GF(256) Vandermonde matrix. Ordinary `moon test` uses committed vectors and requires no Go installation. CI additionally regenerates them using the pinned Go module and checks for drift; the setup and reproduction commands are in the comparison document. This establishes agreement on the tested configurations, not universal interoperability with every matrix or Leopard mode.

## Design and license

See [architecture](docs/ARCHITECTURE.md), [domain glossary](CONTEXT.md), [decision record](docs/adr/0001-systematic-gf256-shards.md) and [third-party notice](THIRD_PARTY_NOTICES.md). Licensed under [Apache-2.0](LICENSE). No external source code or test corpus was copied into this repository.

## 十月第二轮：批量事务与可恢复区间

`FrameCatalog::add_many(frames, max_frames?)` 在分离槽表上验证所有已解析帧，成功才提交；外部帧字节须先经 CRC 解析，批量操作不提供跨线程或持久化事务。`recoverable_ranges(max_ranges?)` 返回分片数量足够的最大连续半开字节区间，不解码整对象，也不认证分片内容。范围读取的参数是起点和长度：`recover_range(range.start(), range.length())`。

运行 `moon run examples/maintenance --target wasm-gc`，展示两段可恢复数据与中间缺失条带。详见 [功能与边界](docs/OCTOBER_FEATURES.md)。

## 当前源码新增：字节区间校验更新

update_parity_ranges 仅需变化区间的旧/新字节，支持同片不重叠多区间和严格预算；完整校验片仍会复制。

运行 `moon run examples/range_update --target wasm-gc`，详见[功能、预算与边界](docs/RANGE_UPDATES.md)。本轮适配官方 MoonBit 0.10.16；受影响的 Windows 环境以 `./tools/windows/moon.ps1` 替代 `moon`。这些修改尚未发布到公共包。

## Source-workspace extensions (unreleased)

Compiler requirement: **moonc >= 0.10.16**. See
[the API, scope and complexity notes](docs/FEATURE_EXTENSIONS.md) for **成本感知修复与故障域暴露分析**.
These additions are available in this source tree; the previously published package
version does not yet contain them. Run the assertion-based example from the repository:

```sh
moon run examples/placement --target wasm-gc --deny-warn
```
