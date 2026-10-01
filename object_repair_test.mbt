///|
test "object repair generates only missing frames" {
  let codec = try! @moonerasure.Codec::new(3, 2)
  let object = try! @moonerasure.encode_object(
    codec,
    b"repairable object across two stripes",
    17,
    stripe_payload_limit=10,
  )
  let kept : Array[@moonerasure.ShardEnvelope] = []
  let lost : Array[@moonerasure.ShardEnvelope] = []
  for frame in object.frames() {
    if frame.shard_index() == frame.stripe_index() % 5 {
      lost.push(frame)
    } else {
      kept.push(frame)
    }
  }
  let repair = try! @moonerasure.repair_object(object.manifest(), kept)
  assert_eq(repair.replacement_count(), lost.length())
  assert_eq(repair.repaired_stripes(), object.manifest().stripe_count())
  let replacement = repair.replacements()
  for index = 0; index < lost.length(); index = index + 1 {
    assert_eq(replacement[index].to_bytes(), lost[index].to_bytes())
    kept.push(replacement[index])
  }
  let restored = try! @moonerasure.recover_object(object.manifest(), kept)
  assert_eq(restored.payload(), b"repairable object across two stripes")
}

///|
test "complete object needs no replacement" {
  let codec = try! @moonerasure.Codec::new(2, 1)
  let object = try! @moonerasure.encode_object(codec, b"complete", 42)
  let repair = try! @moonerasure.repair_object(
    object.manifest(),
    object.frames(),
  )
  assert_eq(repair.replacement_count(), 0)
  assert_eq(repair.repaired_stripes(), 0)
}

///|
test "repair fails when any stripe has too few frames" {
  let codec = try! @moonerasure.Codec::new(3, 2)
  let object = try! @moonerasure.encode_object(
    codec,
    b"two-stripe-object",
    9,
    stripe_payload_limit=8,
  )
  let kept : Array[@moonerasure.ShardEnvelope] = []
  for frame in object.frames() {
    if frame.stripe_index() != 0 || frame.shard_index() < 2 {
      kept.push(frame)
    }
  }
  let error = try @moonerasure.repair_object(object.manifest(), kept) catch {
    error => error.code()
  } noraise {
    _ => "unexpected success"
  }
  assert_eq(error, "ERASURE_NOT_ENOUGH_SHARDS")
}
