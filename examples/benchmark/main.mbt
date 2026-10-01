///|
/// Fixed workload for measuring encoding and repeated-pattern decoding with
/// an external wall-clock tool. No result is published as a universal speed.
fn main raise {
  let codec = try! @lib.Codec::new(6, 3)
  let session = try! @lib.RecoverySession::new(codec)
  let data : Array[Bytes] = []
  for shard = 0; shard < 6; shard = shard + 1 {
    let bytes = Array::make(8192, b'\x00')
    for position = 0; position < bytes.length(); position = position + 1 {
      bytes[position] = ((shard * 61 + position * 13) % 256).to_byte()
    }
    data.push(Bytes::from_array(bytes))
  }
  let mut checked_bytes = 0
  for round = 0; round < 20; round = round + 1 {
    let encoded = try! codec.encode_all(data)
    let erased : Array[Bytes?] = []
    for index = 0; index < encoded.length(); index = index + 1 {
      if index == 1 || index == 7 {
        erased.push(None)
      } else {
        erased.push(Some(encoded[index]))
      }
    }
    let restored = try! session.reconstruct(erased)
    assert_eq(restored, encoded)
    checked_bytes = checked_bytes + 6 * 8192
  }
  assert_eq(session.cache_misses(), 1)
  assert_eq(session.cache_hits(), 19)
  println("verified source bytes: " + checked_bytes.to_string())
  println("matrix cache hits: " + session.cache_hits().to_string())
  println("benchmark workload: ok")
}
