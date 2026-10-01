///|
test "health report separates healthy repairable and unrecoverable stripes" {
  let codec = try! @moonerasure.Codec::new(3, 2)
  let object = try! @moonerasure.encode_object(
    codec,
    b"abcdefghijklmnopqrstuvwx",
    23,
    stripe_payload_limit=8,
  )
  let retained : Array[@moonerasure.ShardEnvelope] = []
  for frame in object.frames() {
    if frame.stripe_index() == 0 ||
      (frame.stripe_index() == 1 && frame.shard_index() >= 2) ||
      (frame.stripe_index() == 2 && frame.shard_index() >= 3) {
      retained.push(frame)
    }
  }
  let report = try! @moonerasure.inspect_object(object.manifest(), retained)
  assert_eq(report.healthy_count(), 1)
  assert_eq(report.repairable_count(), 1)
  assert_eq(report.unrecoverable_count(), 1)
  assert_false(report.fully_recoverable())
  assert_eq(report.stripes()[1].status().label(), "repairable")
  assert_eq(report.stripes()[2].missing_indices(), [0, 1, 2])
}

///|
test "health report rejects inconsistent otherwise sufficient frames" {
  let codec = try! @moonerasure.Codec::new(2, 1)
  let original = try! @moonerasure.encode_stripe(codec, b"abcd", 3, 0)
  let conflicting = try! @moonerasure.ShardEnvelope::new(
    codec, 3, 0, 2, 4, b"zz",
  )
  let report = @moonerasure.inspect_stripe(
    codec,
    [original[0], original[1], conflicting],
    3,
    0,
  )
  assert_eq(report.status().label(), "invalid-input")
  assert_eq(report.reason_code(), Some("ERASURE_INCONSISTENT_SHARD"))
}
