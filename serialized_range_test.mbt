///|
test "serialized range ignores loss in unrelated stripes" {
  let codec = try! @moonerasure.Codec::new(3, 2)
  let payload = b"abcdefghijKLMNOPQRSTuvwxyz01234"
  let object = try! @moonerasure.encode_object(
    codec,
    payload,
    14,
    stripe_payload_limit=10,
  )
  let inputs : Array[Bytes] = []
  for frame in object.frames() {
    if frame.stripe_index() == 1 && frame.shard_index() != 0 {
      inputs.push(frame.to_bytes())
    }
  }
  let result = try! @moonerasure.recover_serialized_range(
    object.manifest(),
    inputs,
    12,
    5,
  )
  assert_eq(result.payload(), b"MNOPQ")
  assert_eq(result.issues().length(), 0)
}

///|
test "serialized range reports damaged frame and recovers with parity" {
  let codec = try! @moonerasure.Codec::new(3, 2)
  let payload = b"abcdefghijKLMNOPQRST"
  let object = try! @moonerasure.encode_object(
    codec,
    payload,
    14,
    stripe_payload_limit=10,
  )
  let inputs : Array[Bytes] = []
  for frame in object.frames() {
    if frame.stripe_index() == 1 && frame.shard_index() != 0 {
      let wire = frame.to_bytes().to_array()
      if frame.shard_index() == 4 {
        wire[wire.length() - 1] = (wire[wire.length() - 1].to_int() ^ 1).to_byte()
      }
      inputs.push(Bytes::from_array(wire))
    }
  }
  let result = try! @moonerasure.recover_serialized_range(
    object.manifest(),
    inputs,
    10,
    7,
  )
  assert_eq(result.payload(), b"KLMNOPQ")
  assert_eq(result.issues().length(), 1)
}
