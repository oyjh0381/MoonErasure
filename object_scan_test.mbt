///|
test "serialized object recovers one damaged shard in each stripe" {
  let codec = try! @moonerasure.Codec::new(3, 2)
  let object = try! @moonerasure.encode_object(
    codec,
    b"objects can cross many independent stripes",
    12,
    stripe_payload_limit=9,
  )
  let raw : Array[Bytes] = []
  for frame in object.frames() {
    let bytes = frame.to_bytes().to_array()
    if frame.shard_index() == frame.stripe_index() % codec.total_count() {
      bytes[32] = (bytes[32].to_int() ^ 1).to_byte()
    }
    raw.push(Bytes::from_array(bytes))
  }
  let restored = try! @moonerasure.recover_serialized_object(
    object.manifest(),
    raw,
  )
  assert_eq(
    restored.recovery().payload(),
    b"objects can cross many independent stripes",
  )
  assert_eq(restored.issues().length(), object.manifest().stripe_count())
  assert_eq(
    restored.recovery().repaired_shard_count(),
    object.manifest().stripe_count(),
  )
}

///|
test "scanner enforces aggregate byte budget before parsing" {
  let codec = try! @moonerasure.Codec::new(2, 1)
  let frame = (try! @moonerasure.encode_stripe(codec, b"abcd", 1, 0))[0].to_bytes()
  let rejected = try
    @moonerasure.scan_frames([frame, frame], max_total_bytes=frame.length())
  catch {
    @moonerasure.ResourceLimit(_) => true
    _ => false
  } noraise {
    _ => false
  }
  assert_true(rejected)
}
