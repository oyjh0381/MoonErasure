///|
test "catalog indexes unordered frames and reports erasure capacity" {
  let codec = try! @moonerasure.Codec::new(3, 2)
  let object = try! @moonerasure.encode_object(
    codec,
    b"catalog backed object",
    8,
    stripe_payload_limit=7,
  )
  let catalog = @moonerasure.FrameCatalog::new(object.manifest())
  let frames = object.frames()
  for index = frames.length() - 1; index >= 0; index = index - 1 {
    let frame = frames[index]
    if frame.shard_index() != 0 && frame.shard_index() != 4 {
      try! catalog.add(frame)
    }
  }
  assert_eq(catalog.capacity(), object.frame_count())
  for index = 0; index < object.manifest().stripe_count(); index = index + 1 {
    assert_eq(try! catalog.missing_indices(index), [0, 4])
    assert_true(try! catalog.stripe_recoverable(index))
    let recovered = try! catalog.recover_stripe(index)
    assert_eq(recovered.missing_indices(), [0, 4])
  }
}

///|
test "catalog rejects duplicate without changing count" {
  let codec = try! @moonerasure.Codec::new(2, 1)
  let object = try! @moonerasure.encode_object(codec, b"abc", 9)
  let catalog = @moonerasure.FrameCatalog::new(object.manifest())
  let frame = object.frames()[0]
  try! catalog.add(frame)
  let result = try catalog.add(frame) catch {
    error => error.code()
  } noraise {
    _ => "unexpected success"
  }
  assert_eq(result, "ERASURE_DUPLICATE_INDEX")
  assert_eq(catalog.stored_count(), 1)
}
