# Contributing

MoonErasure accepts focused changes that preserve the documented erasure model and version 1 wire format. Discuss incompatible format or matrix changes before implementation; a new version and migration plan are required. Storage, transport, authentication and placement adapters should remain outside the portable core unless there is a broadly reusable interface.

Before submitting a change, run:

```sh
moon fmt
moon info
moon check --target all --deny-warn
moon build --target all --deny-warn
moon test --target all --deny-warn
moon run cmd/main --target wasm-gc
```

Inspect any `.mbti` diff and commit it when the public interface intentionally changes. Add a regression test for a correctness fix and at least one runnable scenario for a new integration workflow. Preserve resource limits at every parse or allocation boundary. Avoid importing private, commercial or unattributed fixtures. Document the origin and license of any third-party source, vector or asset before adding it.

Reports about malformed input, unintended allocation, wrong recovery or format incompatibility should include a minimal test case, target backend, MoonBit toolchain version and expected versus actual behavior. Do not attach live credentials or private data.
