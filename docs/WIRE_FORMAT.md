# Version 1 wire formats

All multibyte integers are unsigned little-endian on the wire. Readers reject 32-bit fields above `0x7fffffff` where converted to portable MoonBit `Int`. Unknown versions, nonzero reserved fields, truncation, trailing archive bytes and inconsistent checksums fail closed. Each format has a distinct four-byte ASCII magic.

## Shard frame (`MERS`)

| Offset | Bytes | Meaning |
| --- | ---: | --- |
| 0 | 4 | `MERS` magic |
| 4 | 1 | Version `1` |
| 5 | 1 | Flags, currently `0` |
| 6 | 2 | Header size, `32` |
| 8 | 4 | Nonnegative set id |
| 12 | 4 | Nonnegative stripe index |
| 16 | 2 | Shard index in `[0, k + m)` |
| 18 | 2 | Data shard count `k` |
| 20 | 2 | Parity shard count `m` |
| 22 | 2 | Reserved zero |
| 24 | 4 | Unpadded original stripe length |
| 28 | 4 | CRC-32C of bytes `0..27` followed by payload bytes |
| 32 | variable | Shard payload, exactly `ceil(original length / k)` bytes |

Every frame of one stripe repeats dimensions and original length so it can be parsed independently. A CRC failure is reported by source input position in scanner APIs; the header's shard index is not trusted after failure. Individual frames contain no manifest total length or cryptographic digest.

## Object manifest (`MERM`)

| Offset | Bytes | Meaning |
| --- | ---: | --- |
| 0 | 4 | `MERM` magic |
| 4 | 1 | Version `1` |
| 5 | 1 | Reserved zero |
| 6 | 2 | Header size, `32` |
| 8 | 4 | Set id |
| 12 | 2 | `k` |
| 14 | 2 | `m` |
| 16 | 4 | Stripe payload limit |
| 20 | 4 | Stripe count, equal to ceiling of total length divided by limit |
| 24 | 4 | Total unpadded object length |
| 28 | 4 | CRC-32C of bytes `0..27` |

The empty object has zero stripes and zero frames. The manifest must be protected by the application's durability and authenticity scheme. It has a checksum but no signature.

## Bundle (`MERB`)

The bundle starts with a 24-byte header: magic `MERB` at offset 0, version `1` at 4, zero flags at 5, header length 24 at 6, manifest length 32 at 8, frame count at 12, reserved zero at 16, and CRC-32C of bytes `0..19` at 20. A 32-byte manifest follows. Each frame is preceded by its 32-bit little-endian encoded length and then its complete `MERS` bytes. The importer requires the frame count to equal `stripe_count × (k + m)` and validates all stripes. It rejects appended bytes. An archive is a convenient single-file representation; independent frames are preferred when placement across failure domains matters.

The version is part of each header. Changing any field interpretation or parity construction requires a new version and migration tooling; current parsers never guess a newer layout.
