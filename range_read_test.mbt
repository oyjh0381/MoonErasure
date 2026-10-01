///|
test "all valid object ranges agree with original bytes" {
  let codec = try! @moonerasure.Codec::new(3, 2)
  let payload = b"recover only the requested byte range"
  let encoded = try! @moonerasure.encode_object(
    codec,
    payload,
    5,
    stripe_payload_limit=8,
  )
  let retained : Array[@moonerasure.ShardEnvelope] = []
  for frame in encoded.frames() {
    if frame.shard_index() != frame.stripe_index() % codec.total_count() &&
      frame.shard_index() != (frame.stripe_index() + 1) % codec.total_count() {
      retained.push(frame)
    }
  }
  for start = 0; start <= payload.length(); start = start + 1 {
    for length = 0; length <= payload.length() - start; length = length + 1 {
      let result = try! @moonerasure.recover_object_range(
        encoded.manifest(),
        retained,
        start,
        length,
      )
      assert_eq(result, Bytes::from_array(payload[start:start + length].to_array()))
    }
  }
}

///|
test "range read needs only intersecting stripe packets" {
  let codec = try! @moonerasure.Codec::new(2, 1)
  let encoded = try! @moonerasure.encode_object(
    codec,
    b"abcdefghij",
    7,
    stripe_payload_limit=4,
  )
  let second_only : Array[@moonerasure.ShardEnvelope] = []
  for frame in encoded.frames() {
    if frame.stripe_index() == 1 && frame.shard_index() != 0 {
      second_only.push(frame)
    }
  }
  assert_eq(
    try! @moonerasure.recover_object_range(
      encoded.manifest(),
      second_only,
      5,
      2,
    ),
    b"fg",
  )
}
