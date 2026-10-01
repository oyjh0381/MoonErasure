///|
test "bundle stream accepts every chunk width" {
  let codec = try! @moonerasure.Codec::new(3, 2)
  let object = try! @moonerasure.encode_object(
    codec,
    b"streaming bundle input split at arbitrary boundaries",
    7,
    stripe_payload_limit=13,
  )
  let bytes = try! @moonerasure.export_bundle(object)
  for width = 1; width <= bytes.length(); width = width + 1 {
    let stream = try! @moonerasure.BundleStream::new()
    let frames : Array[@moonerasure.ShardEnvelope] = []
    let mut offset = 0
    while offset < bytes.length() {
      let mut end = offset + width
      if end > bytes.length() {
        end = bytes.length()
      }
      let chunk = Bytes::from_array(bytes[offset:end].to_array())
      let completed = try! stream.push(chunk)
      for frame in completed {
        frames.push(frame)
      }
      offset = end
    }
    let manifest = try! stream.finish()
    assert_eq(stream.parsed_frame_count(), object.frame_count())
    assert_eq(
      (try! @moonerasure.recover_object(manifest, frames)).payload(),
      b"streaming bundle input split at arbitrary boundaries",
    )
  }
}

///|
test "bundle stream refuses incomplete input and trailing bytes" {
  let codec = try! @moonerasure.Codec::new(2, 1)
  let object = try! @moonerasure.encode_object(codec, b"abcd", 1)
  let bytes = try! @moonerasure.export_bundle(object)
  let incomplete = try! @moonerasure.BundleStream::new()
  ignore(
    try! incomplete.push(
      Bytes::from_array(bytes[0:bytes.length() - 1].to_array()),
    ),
  )
  let truncated = try incomplete.finish() catch {
    @moonerasure.InvalidEnvelope(_) => true
    _ => false
  } noraise {
    _ => false
  }
  assert_true(truncated)
  let complete = try! @moonerasure.BundleStream::new()
  ignore(try! complete.push(bytes))
  let trailing = try complete.push(b"!") catch {
    @moonerasure.InvalidEnvelope(_) => true
    _ => false
  } noraise {
    _ => false
  }
  assert_true(trailing)
}
