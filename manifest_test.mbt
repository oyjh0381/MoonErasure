///|
test "manifest roundtrip records exact final stripe length" {
  let codec = try! @moonerasure.Codec::new(3, 2)
  let manifest = try! @moonerasure.Manifest::new(codec, 7, 10, 24)
  assert_eq(manifest.stripe_count(), 3)
  assert_eq(try! manifest.stripe_length(0), 10)
  assert_eq(try! manifest.stripe_length(1), 10)
  assert_eq(try! manifest.stripe_length(2), 4)
  let decoded = try! @moonerasure.Manifest::from_bytes(manifest.to_bytes())
  assert_eq(decoded.set_id(), 7)
  assert_eq(decoded.stripe_payload_limit(), 10)
  assert_eq(decoded.total_length(), 24)
}

///|
test "empty object has zero stripes" {
  let codec = try! @moonerasure.Codec::new(2, 1)
  let manifest = try! @moonerasure.Manifest::new(codec, 0, 10, 0)
  assert_eq(manifest.stripe_count(), 0)
  assert_eq(
    (try! @moonerasure.Manifest::from_bytes(manifest.to_bytes())).total_length(),
    0,
  )
}
