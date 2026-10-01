# ADR 0001 — Systematic GF(256) erasure coding

Status: accepted for the initial local implementation (2026-10-01).

## Context

The library must let callers keep ordinary data shards readable while recovering several missing shards from any sufficiently large subset. A single XOR parity shard only handles one erasure. Replicating entire objects has simple reads but its storage overhead grows linearly with the replica count. Rateless codes offer different trade-offs and a much larger protocol surface.

## Decision

Use a systematic Reed–Solomon generator matrix over GF(2^8), built by normalizing a Vandermonde matrix whose first rows become the identity. Require `data_count >= 1`, `parity_count >= 1`, and total count `<= 256`. The pure MoonBit core accepts byte shards and reports invalid configurations, missing-shard shortages and malformed envelopes as typed errors. Storage, network transport and trust policy remain outside the core.

## Consequences

Any `data_count` distinct, intact shards should reconstruct a stripe; this property is tested across small exhaustive loss patterns. Encoding costs proportional to shard bytes times the data/parity product, and matrix inversion adds cubic work during repair. GF(256) limits total shards to 256 and does not identify unknown bit corruption. The envelope checksum detects accidental damage but is not an authenticity mechanism.

The field polynomial and matrix layout must be fixed in the format version. Changing either would make old parity bytes incompatible, so the wire format records a version and rejects unsupported versions.
