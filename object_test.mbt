///|
test "multi-stripe object recovers different losses per stripe" {
  let codec = try! @moonerasure.Codec::new(3, 2)
  let encoded = try! @moonerasure.encode_object(
    codec,
    b"This backup spans several independently repaired stripes.",
    29,
    stripe_payload_limit=12,
  )
  assert_true(encoded.manifest().stripe_count() > 2)
  let retained : Array[@moonerasure.ShardEnvelope] = []
  for frame in encoded.frames() {
    let lost = (frame.stripe_index() + frame.shard_index()) % 5
    if lost >= 2 {
      retained.push(frame)
    }
  }
  let repaired = try! @moonerasure.recover_object(encoded.manifest(), retained)
  assert_eq(
    repaired.payload(),
    b"This backup spans several independently repaired stripes.",
  )
  assert_true(repaired.repaired_shard_count() > 0)
}

///|
test "empty object has a valid manifest and no frames" {
  let codec = try! @moonerasure.Codec::new(2, 1)
  let encoded = try! @moonerasure.encode_object(codec, b"", 0)
  assert_eq(encoded.frame_count(), 0)
  let recovered = try! @moonerasure.recover_object(encoded.manifest(), [])
  assert_eq(recovered.payload(), b"")
  assert_eq(recovered.stripe_count(), 0)
}
