# Source and license notes

MoonErasure runtime source, examples and handwritten tests were written for this project and are offered under the repository's Apache-2.0 license. There is no vendored third-party runtime implementation. The GF(256) arithmetic and Reed–Solomon construction implement public mathematics; [RFC 5510](https://datatracker.ietf.org/doc/html/rfc5510) was consulted for algorithm concepts. [Backblaze JavaReedSolomon](https://github.com/Backblaze/JavaReedSolomon) is cited as a contextual implementation of the storage use case, not ported or copied.

The development-only module in `tools/reference/` uses [`klauspost/reedsolomon` v1.14.2](https://github.com/klauspost/reedsolomon/tree/v1.14.2), licensed under [MIT](https://github.com/klauspost/reedsolomon/blob/v1.14.2/LICENSE). No implementation source was translated or copied. Our original Go helper generates `testdata/reedsolomon-v1.14.2.json`; our Python helper converts these behavioral outputs to `reference_vectors_generated_test.mbt`. These are deterministic reference-generated test data, not handwritten implementation, and are excluded from handwritten LOC. Go modules resolve development dependencies with their own upstream licenses; MoonErasure has no Go runtime dependency. Functional comparison, matrix restrictions and reproduction commands are in [REFERENCE_COMPARISON.md](docs/REFERENCE_COMPARISON.md).

Its locked development-only indirect dependencies are [`klauspost/cpuid/v2` v2.3.0](https://github.com/klauspost/cpuid/tree/v2.3.0) (MIT) and [`golang.org/x/sys` v0.30.0](https://github.com/golang/sys/tree/v0.30.0) (BSD-3-Clause). Their implementation files are fetched by Go for reference generation and are not vendored or translated into the MoonBit package.

The hand-computed byte vector in `codec_properties_test.mbt` follows directly from this project's documented normalized matrix construction. The example strings are original synthetic text. No third-party images, binary assets, credentials or private code are included.

The project license is [Apache License 2.0](LICENSE), an OSI-approved license. Users must separately check licenses for applications and data they combine with this library.

The optional tools/windows argv compatibility utility is reused from the workspace MoonUriTemplate/MoonTUF Apache-2.0 utility. It only launches official tools with normalized DOS path prefixes. The new range_update functionality and tests are original, AI-assisted MoonBit code; no external implementation was copied.
