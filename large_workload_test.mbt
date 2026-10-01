///|
test "larger binary object survives two losses on every stripe" {
  let codec = try! @moonerasure.Codec::new(6, 3)
  let bytes = Array::make(65_537, b'\x00')
  for index = 0; index < bytes.length(); index = index + 1 {
    bytes[index] = ((index * 73 + index / 251 + 19) % 256).to_byte()
  }
  let payload = Bytes::from_array(bytes)
  let object = try! @moonerasure.encode_object(
    codec,
    payload,
    982,
    stripe_payload_limit=4096,
  )
  let retained : Array[@moonerasure.ShardEnvelope] = []
  for frame in object.frames() {
    let lost_a = frame.stripe_index() % codec.total_count()
    let lost_b = (lost_a + 4) % codec.total_count()
    if frame.shard_index() != lost_a && frame.shard_index() != lost_b {
      retained.push(frame)
    }
  }
  let recovered = try! @moonerasure.recover_object(object.manifest(), retained)
  assert_eq(recovered.payload(), payload)
  assert_eq(recovered.stripe_count(), 17)
  assert_eq(recovered.repaired_shard_count(), 34)
}

///|
test "large incremental stream keeps at most one stripe internally" {
  let codec = try! @moonerasure.Codec::new(4, 2)
  let bytes = Array::make(32_777, b'\x00')
  for index = 0; index < bytes.length(); index = index + 1 {
    bytes[index] = ((index * 11 + 37) % 256).to_byte()
  }
  let payload = Bytes::from_array(bytes)
  let encoder = try! @moonerasure.ObjectEncoder::new(
    codec,
    31,
    payload.length(),
    stripe_payload_limit=1024,
  )
  let frames : Array[@moonerasure.ShardEnvelope] = []
  let mut offset = 0
  while offset < payload.length() {
    let mut end = offset + 137
    if end > payload.length() {
      end = payload.length()
    }
    let emitted = try! encoder.push(Bytes::from_array(payload[offset:end].to_array()))
    for frame in emitted {
      frames.push(frame)
    }
    assert_true(encoder.buffered_bytes() < 1024)
    offset = end
  }
  let manifest = try! encoder.finish()
  let decoder = try! @moonerasure.ObjectDecoder::new(manifest)
  let output : Array[Byte] = []
  for stripe = 0; stripe < manifest.stripe_count(); stripe = stripe + 1 {
    let group : Array[@moonerasure.ShardEnvelope] = []
    for frame in frames {
      if frame.stripe_index() == stripe && frame.shard_index() != 1 {
        group.push(frame)
      }
    }
    let chunk = try! decoder.push_stripe(group)
    for byte in chunk {
      output.push(byte)
    }
  }
  assert_eq(try! decoder.finish(), manifest.stripe_count())
  assert_eq(Bytes::from_array(output), payload)
}
