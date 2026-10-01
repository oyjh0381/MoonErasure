///|
test "bundle roundtrip preserves complete object" {
  let codec = try! @moonerasure.Codec::new(3, 2)
  let original = try! @moonerasure.encode_object(
    codec,
    b"multi-stripe backup payload",
    19,
    stripe_payload_limit=8,
  )
  let encoded = try! @moonerasure.export_bundle(original)
  let restored = try! @moonerasure.import_bundle(encoded)
  assert_eq(restored.frame_count(), original.frame_count())
  assert_eq(restored.manifest().to_bytes(), original.manifest().to_bytes())
  assert_eq(
    (try! @moonerasure.recover_object(restored.manifest(), restored.frames())).payload(),
    b"multi-stripe backup payload",
  )
  assert_eq(try! @moonerasure.export_bundle(restored), encoded)
}

///|
test "bundle import rejects truncation and trailing data" {
  let codec = try! @moonerasure.Codec::new(2, 1)
  let object = try! @moonerasure.encode_object(codec, b"abcde", 4)
  let encoded = try! @moonerasure.export_bundle(object)
  let truncated = Bytes::from_array(encoded[0:encoded.length() - 1].to_array())
  let rejected_truncation = try @moonerasure.import_bundle(truncated) catch {
    @moonerasure.InvalidEnvelope(_) => true
    _ => false
  } noraise {
    _ => false
  }
  assert_true(rejected_truncation)
  let longer = encoded.to_array()
  longer.push(b'!')
  let rejected_tail = try
    @moonerasure.import_bundle(Bytes::from_array(longer))
  catch {
    @moonerasure.InvalidEnvelope(_) => true
    _ => false
  } noraise {
    _ => false
  }
  assert_true(rejected_tail)
}
