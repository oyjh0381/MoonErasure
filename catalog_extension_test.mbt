///|
test "catalog invalidation and CRC admission support repair cycle" {
  let codec = try! @moonerasure.Codec::new(3, 2)
  let object = try! @moonerasure.encode_object(codec, b"repair data", 6)
  let catalog = @moonerasure.FrameCatalog::new(object.manifest())
  let frames = object.frames()
  for frame in frames {
    try! catalog.add_bytes(frame.to_bytes())
  }
  assert_eq(catalog.stored_count(), catalog.capacity())
  assert_true(try! catalog.invalidate(0, 1))
  assert_true(!(try! catalog.invalidate(0, 1)))
  assert_eq(catalog.stored_count(), catalog.capacity() - 1)
  let damaged = frames[1].to_bytes().to_array()
  damaged[damaged.length() - 1] = (damaged[damaged.length() - 1].to_int() ^ 1).to_byte()
  let code = try catalog.add_bytes(Bytes::from_array(damaged)) catch {
    error => error.code()
  } noraise {
    _ => "unexpected success"
  }
  assert_eq(code, "ERASURE_CHECKSUM")
  assert_eq(catalog.stored_count(), catalog.capacity() - 1)
  let recovered = try! catalog.recover_stripe(0)
  try! catalog.add_bytes(recovered.shards()[1].to_bytes())
  assert_eq(catalog.stored_count(), catalog.capacity())
}

///|
test "catalog range decodes only intersecting stripes" {
  let codec = try! @moonerasure.Codec::new(3, 2)
  let object = try! @moonerasure.encode_object(
    codec,
    b"abcdefghijKLMNOPQRSTuvwxyz",
    7,
    stripe_payload_limit=10,
  )
  let catalog = @moonerasure.FrameCatalog::new(object.manifest())
  for frame in object.frames() {
    if frame.stripe_index() == 1 && frame.shard_index() != 0 {
      try! catalog.add(frame)
    }
  }
  assert_eq(try! catalog.recover_range(12, 5), b"MNOPQ")
  assert_eq(try! catalog.recover_range(0, 0), b"")
  let code = try catalog.recover_range(0, 1) catch {
    error => error.code()
  } noraise {
    _ => "unexpected success"
  }
  assert_eq(code, "ERASURE_NOT_ENOUGH_SHARDS")
}
