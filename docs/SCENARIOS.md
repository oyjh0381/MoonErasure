# Three reproducible application workflows

All commands run from a source checkout and assert expected bytes. These are in-memory storage-adapter workloads, not completed network or filesystem services. A real adapter supplies verified shards, node placement, authentication and durable generation commits.

| Need and reusable callers | Inputs and faults | Command | Verified outcome |
| --- | --- | --- | --- |
| Degraded block reads: object gateways, backup browsers, chunk readers | 6+3, 4 KiB per shard; one data and two parity slots missing; request the data slot | `moon run examples/degraded_read --target wasm-gc` | Original data block returned; other erased slots stay absent; returned bytes 4,096 instead of a 36,864-byte complete codeword |
| Partial updates: block stores, segment stores, mutable backup chunks | 10+4, 4 KiB blocks; change one data block; later erase that block and three parity slots | `moon run examples/incremental_update --target wasm-gc` | Delta parity equals full re-encoding; original parity unchanged; updated block still recovered after four erasures |
| Targeted repair: storage scrubbers, failed-placement rebuilders, archive maintenance | 6+3, 2 KiB blocks; two data and one parity placements unavailable | `moon run examples/selective_repair --target wasm-gc` | Three requested replacements restore a verified codeword; replacement payload is 6,144 bytes, not 18,432 bytes |

## What the cost numbers establish

Selective recovery reduces returned-shard memory when only a few slots are needed. It does **not** lower the mathematical `k`-input requirement or establish a disk-throughput speedup. Surplus supplied shards remain checked; that work can dominate when many shards are provided. Dense inversion is still needed when the selected basis includes parity.

For the update workload the method receives one old block, one new block and four old parity blocks: `(2+4)*4096 = 24576` bytes. Complete parity encoding consumes `10*4096 = 40960` data bytes. These count method inputs; the example's extra full encoding is an assertion oracle. It is not a physical I/O measurement. Delta updates reduce storage reads only when `2c+m < k` under this input model, and require a consistent old generation plus atomic host persistence.

For `c` changed data shards of length `L`, delta parity computation costs `O((c+1)mL)` including parity copying, versus `O(kmL)` for full parity encoding. When most data shards change, full encoding may be preferable. For an erasure basis, selected recovery costs up to `O(k^3 + p*k^2 + (d+e)*k*L + r*L + n)`, where `d` is requested missing rows, `e` is supplied surplus rows, `p` is parity rows among those computations, `r` is requested outputs and `n=k+m`. Working memory excluding caller input is `O(k^2 + rL + n)`; it does not allocate unrequested erased rows. With all data present, inversion and parity-basis transformation are skipped.

The preceding backup, packet transfer, range, streaming and catalog examples remain supported. Each new command runs in CI and can also run on JS, Native and Wasm; ordinary tests cover all four backends.
