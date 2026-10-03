///|
test "catalog batch commits every valid frame together" {
  let codec = try! @moonerasure.Codec::new(2, 1)
  let object = try! @moonerasure.encode_object(codec, b"abcdef", 101)
  let catalog = @moonerasure.FrameCatalog::new(object.manifest())
  assert_eq(try! catalog.add_many(object.frames()), 3)
  assert_eq(catalog.stored_count(), 3)
  assert_eq(try! catalog.recover_range(0, 6), b"abcdef")
  assert_eq(try! catalog.add_many([], max_frames=0), 0)
}

///|
test "late identity failure rolls back the whole catalog batch" {
  let codec = try! @moonerasure.Codec::new(2, 1)
  let first = try! @moonerasure.encode_object(codec, b"abc", 101)
  let other = try! @moonerasure.encode_object(codec, b"abc", 102)
  let catalog = @moonerasure.FrameCatalog::new(first.manifest())
  try! catalog.add(first.frames()[0])
  ignore(catalog.add_many([first.frames()[1], other.frames()[2]])) catch {
    @moonerasure.ErasureError::InvalidEnvelope(_) => ()
    _ => fail("expected foreign object rejection")
  }
  assert_eq(catalog.stored_count(), 1)
  assert_true(try! (catalog.get(0, 1) is None))
}

///|
test "duplicate and batch limit errors preserve catalog state" {
  let codec = try! @moonerasure.Codec::new(2, 1)
  let object = try! @moonerasure.encode_object(codec, b"abc", 103)
  let catalog = @moonerasure.FrameCatalog::new(object.manifest())
  let frame = object.frames()[0]
  ignore(catalog.add_many([frame, frame])) catch {
    @moonerasure.ErasureError::DuplicateIndex(_) => ()
    _ => fail("expected duplicate rejection")
  }
  assert_eq(catalog.stored_count(), 0)
  ignore(catalog.add_many([frame], max_frames=0)) catch {
    @moonerasure.ErasureError::ResourceLimit(_) => ()
    _ => fail("expected budget rejection")
  }
  assert_eq(catalog.stored_count(), 0)
}

///|
test "availability ranges split missing stripes and clip the final stripe" {
  let codec = try! @moonerasure.Codec::new(2, 1)
  let object = try! @moonerasure.encode_object(
    codec,
    b"abcdefghijk",
    104,
    stripe_payload_limit=4,
  )
  let catalog = @moonerasure.FrameCatalog::new(object.manifest())
  for frame in object.frames() {
    if frame.stripe_index() != 1 && frame.shard_index() < 2 {
      try! catalog.add(frame)
    }
  }
  let ranges = try! catalog.recoverable_ranges()
  assert_eq(ranges.map(range => (range.start(), range.end())), [(0, 4), (8, 11)])
  for range in ranges {
    ignore(try! catalog.recover_range(range.start(), range.length()))
  }
  ignore(catalog.recoverable_ranges(max_ranges=1)) catch {
    @moonerasure.ErasureError::ResourceLimit(_) => ()
    _ => fail("expected range budget rejection")
  }
  for frame in object.frames() {
    if frame.stripe_index() == 1 {
      try! catalog.add(frame)
    }
  }
  assert_eq(
    (try! catalog.recoverable_ranges()).map(range => {
      (range.start(), range.end())
    }),
    [(0, 11)],
  )
  try! (catalog.invalidate(0, 0) |> ignore)
  assert_eq(
    (try! catalog.recoverable_ranges()).map(range => {
      (range.start(), range.end())
    }),
    [(4, 11)],
  )
}

///|
test "empty object has no recovery ranges" {
  let codec = try! @moonerasure.Codec::new(2, 1)
  let object = try! @moonerasure.encode_object(codec, b"", 105)
  let catalog = @moonerasure.FrameCatalog::new(object.manifest())
  assert_eq((try! catalog.recoverable_ranges(max_ranges=0)).length(), 0)
}
