# MoonErasure

MoonErasure is an original, portable MoonBit library for systematic Reed–Solomon erasure coding over byte shards. Its purpose is to let a storage or transfer application recover a stripe from any sufficient set of intact shards. The data shards remain readable without decoding; parity shards supply recovery capacity.

The initial implementation is being developed locally. The public API, tests and runnable examples will be documented here as they are completed. The intended module name is `oyjh0381/moonerasure`.

## Intended use

- Backup and object storage across independent drives or nodes.
- Chunked uploads through unreliable network paths.
- Recovery tests that inject missing fragments deterministically.
- Application-level protection of bounded file stripes.

## Design boundary

The library handles bytes, coding matrices, known erasures, integrity envelopes and stripe assembly. Callers provide storage, transport, retries, access control and authentication. A checksum detects accidental damage; it is not cryptographic proof of origin. The project does not claim to correct arbitrary unknown corruption.

See [topic research](docs/SELECTION_RESEARCH.md), [domain glossary](CONTEXT.md) and [design decision](docs/adr/0001-systematic-gf256-shards.md).

## License

Apache-2.0; see [LICENSE](LICENSE). The algorithm is described in published standards and is implemented independently in MoonBit. No third-party source or test corpus is included.
