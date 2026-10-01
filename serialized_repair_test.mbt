///|
test "serialized repair replaces lost and checksum-failed frames" {
  let codec = try! @moonerasure.Codec::new(3, 2)
  let object = try! @moonerasure.encode_object(
    codec,
    b"replace failed storage frames",
    12,
    stripe_payload_limit=9,
  )
  let inputs : Array[Bytes] = []
  let expected_missing : Array[@moonerasure.ShardEnvelope] = []
  for frame in object.frames() {
    if frame.shard_index() == 0 {
      expected_missing.push(frame)
    } else if frame.shard_index() == 4 {
      expected_missing.push(frame)
      let bytes = frame.to_bytes().to_array()
      bytes[bytes.length() - 1] = (bytes[bytes.length() - 1].to_int() ^ 1).to_byte()
      inputs.push(Bytes::from_array(bytes))
    } else {
      inputs.push(frame.to_bytes())
    }
  }
  let scanned = try! @moonerasure.repair_serialized_object(
    object.manifest(),
    inputs,
  )
  assert_eq(scanned.issues().length(), object.manifest().stripe_count())
  assert_eq(scanned.repair().replacement_count(), expected_missing.length())
  let replacement = scanned.repair().replacements()
  for index = 0; index < replacement.length(); index = index + 1 {
    assert_eq(replacement[index].to_bytes(), expected_missing[index].to_bytes())
  }
}

///|
test "serialized repair refuses damage exceeding parity capacity" {
  let codec = try! @moonerasure.Codec::new(3, 1)
  let object = try! @moonerasure.encode_object(codec, b"data", 1)
  let inputs : Array[Bytes] = []
  for frame in object.frames() {
    if frame.shard_index() >= 2 {
      inputs.push(frame.to_bytes())
    }
  }
  let code = try
    @moonerasure.repair_serialized_object(object.manifest(), inputs)
  catch {
    error => error.code()
  } noraise {
    _ => "unexpected success"
  }
  assert_eq(code, "ERASURE_NOT_ENOUGH_SHARDS")
}
