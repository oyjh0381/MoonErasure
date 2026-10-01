///|
test "envelope roundtrip preserves metadata and data" {
  let codec = try! @moonerasure.Codec::new(3, 2)
  let envelope = try! @moonerasure.ShardEnvelope::new(
    codec,
    42,
    7,
    4,
    8,
    b"abc",
  )
  let decoded = try! @moonerasure.ShardEnvelope::from_bytes(envelope.to_bytes())
  assert_eq(decoded.set_id(), 42)
  assert_eq(decoded.stripe_index(), 7)
  assert_eq(decoded.shard_index(), 4)
  assert_eq(decoded.data_count(), 3)
  assert_eq(decoded.parity_count(), 2)
  assert_eq(decoded.original_length(), 8)
  assert_eq(decoded.payload(), b"abc")
}

///|
test "envelope rejects damaged payload" {
  let codec = try! @moonerasure.Codec::new(2, 1)
  let envelope = try! @moonerasure.ShardEnvelope::new(codec, 1, 0, 0, 4, b"ab")
  let bytes = envelope.to_bytes().to_array()
  bytes[32] = b'x'
  let rejected = try @moonerasure.ShardEnvelope::from_bytes(Bytes::from_array(bytes)) catch {
    @moonerasure.ChecksumMismatch(_) => true
    _ => false
  } noraise {
    _ => false
  }
  assert_true(rejected)
}
