# Verification and test strategy

Run `moon check --target all --deny-warn`, `moon build --target all --deny-warn` and `moon test --target all --deny-warn`. The four supported targets are `wasm`, `wasm-gc`, `js` and `native`. Run each `moon run` command from the README to verify that examples still work. Before committing an interface change, run `moon fmt` and `moon info`, then inspect the diff and commit the generated `.mbti` file.

Tests are split into public black-box tests (`*_test.mbt`) and white-box arithmetic and parser tests (`*_wbtest.mbt`). Coverage includes field multiplication/inverse, matrix inverses, a hand-computed `k=2,m=2` vector, all one/two-erasure combinations across small practical dimensions, all three-erasure combinations for `k=6,m=3`, false parity, duplicate indices, conflicting frame identity, checksum damage, malformed headers, truncation, oversized budgets, zero-length object, multi-stripe placement losses, range reads, catalog behavior and incremental chunk widths.

The exhaustive small-dimension tests verify the MDS recovery contract across many independent shard positions rather than a single happy path. They are deterministic and fast enough for CI. They do not prove resistance to maliciously crafted frames or characterize performance at maximum `k=255`; both remain outside the guarantee.

When a regression is found, add a minimal test for the boundary that failed, fix it, and rerun at least the affected backend plus the full all-backend suite before release. For large data workloads, compare memory use and throughput on the intended backend; the code's 256 MiB per-operation input cap is not a process-wide memory cap.
