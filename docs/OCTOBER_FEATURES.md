# October additions and review

The frame catalog now supports a complete storage scrub cycle. `add_bytes` validates the frame wire format and CRC before changing the inventory, so malformed or checksum-failed bytes cannot appear healthy. `invalidate` evicts a suspect slot idempotently, reducing the stored count exactly once; a caller may then reconstruct and admit replacement frame bytes. Both operations are bounded by the manifest's slot count and the supplied encoded-byte budget.

`FrameCatalog::recover_range` provides a partial read directly from an unordered indexed inventory. It gathers only stripes intersecting the requested byte interval and passes them to the existing range decoder. Loss outside that interval does not block the read. The catalog is an in-memory integration helper; callers remain responsible for durable placement, authentication and media-error detection.

New tests cover successful CRC admission, bit-flipped frame rejection without catalog mutation, idempotent invalidation, repair reinsertion, partial read and a failure in the requested stripe. The October charter's external gates still require a public default branch, passing remote CI, mooncakes.io publication and an applicant-authored one-page proposal. Six simultaneous submissions may require organizer confirmation because the charter states one project per entrant in principle.

## 十月第二轮：批量事务与可恢复区间

`FrameCatalog::add_many(frames, max_frames?)` 在分离槽表上验证所有已解析帧，成功才提交；外部帧字节须先经 CRC 解析，批量操作不提供跨线程或持久化事务。`recoverable_ranges(max_ranges?)` 返回分片数量足够的最大连续半开字节区间，不解码整对象，也不认证分片内容。范围读取的参数是起点和长度：`recover_range(range.start(), range.length())`。

运行 `moon run examples/maintenance --target wasm-gc`，展示两段可恢复数据与中间缺失条带。详见 [算法与复杂度](ARCHITECTURE.md)。
