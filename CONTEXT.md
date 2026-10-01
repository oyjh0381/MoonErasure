# Domain glossary

**Payload** — The original ordered bytes the caller wants to preserve or transfer.

**Stripe** — One independently recoverable partition of a payload. A large payload may contain several stripes.

**Data shard** — One systematic piece of a stripe containing original bytes, possibly padded at the end.

**Parity shard** — A computed piece of a stripe that supplies redundancy. It does not replace an original data shard in normal reading.

**Shard index** — A stable zero-based position among the data shards followed by parity shards of one stripe.

**Erasure** — A shard whose complete bytes are unavailable or known damaged. Its index is known; this project does not infer unknown corruption locations from arbitrary bytes.

**Repair** — Reconstructing erased shards from a sufficient set of present shards of the same stripe and codec configuration.

**Envelope** — A versioned, bounded byte record containing shard identity, lengths and a checksum so a damaged or mismatched shard can be rejected before repair.

**Manifest** — The caller-visible description of a multi-stripe payload: stripe order, original length and codec configuration. It is not a cryptographic authenticity claim.
