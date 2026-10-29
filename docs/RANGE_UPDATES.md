# Byte-range parity updates

Version **0.3.0** adds `Codec::update_parity_ranges(parity, changes)`; version
0.2.0 contains whole-shard updates, not this API. A `DataRangeUpdate` gives
data-shard index, byte offset, equal-length nonempty old/new byte ranges. The
operation does not require unchanged data or unchanged regions of changed data.
It returns detached full parity shards and never mutates inputs.

All parity must have the codec's count/length. Ranges must fit a data shard,
must not overlap within one data shard, and may be adjacent or supplied in any
order. Different shards may update the same offsets. Validation precedes output
allocation; invalid/overlapping patches, mismatched lengths and exceeded budgets
produce typed errors without partial results. Defaults: 4096 ranges, 1 MiB total
changed data bytes. Codec stripe budgets still apply.

For m parity shards of length L, p ranges totalling D bytes, sorting costs
O(p log p), parity copying O(mL), and GF work O(mD). Extra output/staging space is
O(mL+p). Compared with the existing full-shard API's O(m*c*L) delta processing,
small changes avoid reading and multiplying unchanged data regions. Full parity
is still read/copied; this is not a sparse network parity-patch format or a
storage speed benchmark. Old/new slices and parity must belong to the same
consistent generation. The API cannot authenticate that premise; hosts commit
new data and parity together.

Run `moon run examples/range_update --target wasm-gc`: change two bytes in a
block, compare to full encoding, recover after two erasures and reject overlap.
This supports VM/backup block edits, database-page adapters and small in-place
record changes. No I/O or durable transaction is performed.

Mutable array/Map fields in readonly public types are now private; callers use
existing methods instead of direct internal fields. This prevents bypassing
codec tables, frame catalogs and recovery state. Use `tools/windows/moon.ps1`
instead of `moon` on the affected official 0.10.16 Windows extended-path release;
the argv utility invokes official tools and restores process-local overrides.
