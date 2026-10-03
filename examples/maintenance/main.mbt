///|
fn main raise {
  let codec = try! @lib.Codec::new(2, 1)
  let object = try! @lib.encode_object(
    codec,
    b"abcdefghijk",
    111,
    stripe_payload_limit=4,
  )
  let catalog = @lib.FrameCatalog::new(object.manifest())
  let selected = object
    .frames()
    .filter(fn(frame) { frame.stripe_index() != 1 && frame.shard_index() < 2 })
  assert_eq(try! catalog.add_many(selected), 4)
  let ranges = try! catalog.recoverable_ranges()
  assert_eq(ranges.length(), 2)
  for range in ranges {
    let bytes = try! catalog.recover_range(range.start(), range.length())
    assert_eq(bytes.length(), range.length())
  }
  println("Atomic catalog admission and available byte ranges: ok")
}
