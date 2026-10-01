///|
test "raw frame health distinguishes recoverable damage and fatal shortage" {
  let codec = try! @moonerasure.Codec::new(3, 2)
  let object = try! @moonerasure.encode_object(
    codec,
    b"firststripeSECONDSTRIPE",
    27,
    stripe_payload_limit=11,
  )
  let inputs : Array[Bytes] = []
  for frame in object.frames() {
    let stripe = frame.stripe_index()
    let shard = frame.shard_index()
    if stripe == 0 && shard == 0 {
      let bytes = frame.to_bytes().to_array()
      bytes[bytes.length() - 1] = (bytes[bytes.length() - 1].to_int() ^ 1).to_byte()
      inputs.push(Bytes::from_array(bytes))
    } else if stripe == 1 && shard >= 2 {
      ()
    } else {
      inputs.push(frame.to_bytes())
    }
  }
  let result = try! @moonerasure.inspect_serialized_object(
    object.manifest(),
    inputs,
  )
  assert_eq(result.issues().length(), 1)
  assert_eq(result.health().repairable_count(), 1)
  assert_eq(result.health().unrecoverable_count(), 1)
  assert_true(!result.health().fully_recoverable())
}

///|
test "raw frame health reports invalid duplicate slot separately" {
  let codec = try! @moonerasure.Codec::new(2, 1)
  let object = try! @moonerasure.encode_object(codec, b"data", 4)
  let inputs : Array[Bytes] = []
  let frames = object.frames()
  inputs.push(frames[0].to_bytes())
  inputs.push(frames[1].to_bytes())
  inputs.push(frames[0].to_bytes())
  let result = try! @moonerasure.inspect_serialized_object(
    object.manifest(),
    inputs,
  )
  assert_eq(result.health().invalid_count(), 1)
  assert_eq(result.issues().length(), 0)
}
