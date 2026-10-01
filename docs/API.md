# API workflows

`oyjh0381/moonerasure` exposes the coding core and object helpers in its root package. Every fallible constructor and operation raises `ErasureError`; call `error.code()` for a stable category suitable for logs. Errors contain no secret payload bytes.

## Raw byte shards

Construct `Codec::new(k, m, max_encoded_bytes?)`. The budget covers `k + m` shards at one stripe, so `max_shard_bytes()` is its integer quotient. `encode(data)` accepts exactly `k` equally sized nonempty `Bytes` values and returns `m` parity shards. `encode_all(data)` returns detached data followed by parity. `verify(shards)` checks all parity against supplied data.

For a known erasure, construct an array of exactly `k + m` options, with `None` at each missing slot, then call `reconstruct`. At least `k` shards are required. Every additional supplied shard is checked against the recovered codeword. `plan(present_flags)` reports selected inputs, missing data/parity indices and shortage before decoding. Raw shards have no integrity proof; use frames when input can be damaged.

For repeated stripe-loss patterns, construct `RecoverySession::new(codec, max_patterns?)` and call its `reconstruct` method. It retains up to 64 selected-row inverse matrices (16 by default), with FIFO eviction. `cache_hits`, `cache_misses` and `cache_size` expose usage. A session is mutable and belongs to one caller; use separate sessions for concurrent workers. It still validates all supplied shard bytes through the normal reconstruction path. Cache benefit depends on repeated erasure patterns; one-off small stripes may not benefit.

## Frame and stripe

`encode_stripe(codec, payload, set_id, stripe_index)` splits a nonempty payload into `k` equal zero-padded data shards, appends parity, and wraps each shard in a `ShardEnvelope`. The envelope carries the set and stripe identity, `k`, `m`, shard index, original length, and CRC-32C. Save `to_bytes()` on independent storage domains. Parse with `ShardEnvelope::from_bytes` and a suitable encoded-byte budget. The parser rejects unexpected version, dimensions, noncanonical lengths, reserved fields, or checksum mismatch.

`recover_stripe(codec, frames, set_id, stripe_index)` accepts any order, rejects duplicates and mixed metadata, reconstructs all shards, and returns original bytes, replacement-ready envelopes and missing indices. `scan_frames` and `recover_serialized_stripe` accept raw frame bytes; damaged raw frames are rejected individually with input positions. The caller decides whether to quarantine, retry or fetch an alternative frame.

## Multi-stripe objects

`encode_object(codec, payload, set_id, stripe_payload_limit?, max_object_bytes?, max_output_bytes?)` returns a `Manifest` and all frames. The manifest records total length and the stripe limit, and has a 32-byte portable representation. Save it durably alongside the frames. `recover_object` groups frames by stripe and reconstructs the original byte sequence. `repair_object` regenerates only missing frames. `recover_serialized_object` and `repair_serialized_object` scan raw frame bytes first and return issue positions. `inspect_object` reports healthy, repairable, unrecoverable and invalid-input stripe counts.

For large inputs with a known length, `ObjectEncoder::new(codec, set_id, total_length, stripe_payload_limit?)` followed by repeated `push(chunk)` calls returns completed frames as each stripe fills. `finish()` confirms the declared byte count. `ObjectDecoder::new(manifest)` followed by `push_stripe(frames)` returns each stripe's payload in order; `finish()` confirms all stripes were consumed. These objects keep only one pending input stripe or decoder state internally; callers should persist outputs instead of holding every returned frame.

`FrameCatalog::new(manifest)` is an optional in-memory index for unordered frame arrivals. `add(frame)` checks identity, lengths and duplicates; `missing_indices`, `stripe_recoverable`, `stripe_frames` and `recover_stripe` support inventory and repair workflows. Catalog admission checks metadata; recovery still verifies the codeword.

## Partial reads and archives

`recover_object_range(manifest, frames, start, length)` decodes only intersecting stripes. `recover_serialized_range` takes raw frames, reports malformed input positions, and does the same. The caller can fetch only frames for those stripes; loss elsewhere does not block the range. An empty valid range returns empty bytes.

`export_bundle(encoded_object)` creates one `MERB` archive containing a manifest and all frames; `import_bundle` strictly validates it and rejects trailing bytes. `BundleStream::push(chunk)` incrementally parses arbitrary chunks and emits completed frames; `finish()` requires the exact end of a bundle. This parser does not retain returned frames, but a large input chunk can contain many outputs. A parser error invalidates that stream instance.

## Choosing budgets

The defaults are suitable for small to moderate objects. Set lower `max_encoded_bytes`, `max_object_bytes`, `max_output_bytes`, `max_input_bytes`, or `max_total_bytes` at trust boundaries. The maximum accepted budget for a single public operation is 256 MiB. This cap limits allocation requests but is not a process-wide memory quota: multiple simultaneous operations and copies can consume more.
