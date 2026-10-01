# Source and license notes

MoonErasure source, examples, tests, fixtures and documentation in this repository were written for this project and are offered under the repository's Apache-2.0 license. There is no vendored third-party code or copied test corpus. The GF(256) arithmetic and Reed–Solomon construction implement public mathematics; [RFC 5510](https://datatracker.ietf.org/doc/html/rfc5510) was consulted for algorithm concepts. [Backblaze JavaReedSolomon](https://github.com/Backblaze/JavaReedSolomon) is cited as a contextual implementation of the storage use case, not ported or copied.

The hand-computed byte vector in `codec_properties_test.mbt` follows directly from this project's documented normalized matrix construction. The example strings are original synthetic text. No third-party images, binary assets, credentials or private code are included.

The project license is [Apache License 2.0](LICENSE), an OSI-approved license. Users must separately check licenses for applications and data they combine with this library.
