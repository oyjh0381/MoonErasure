///|
test "incremental encoder agrees with whole-object encoding" {
  let codec = try! @moonerasure.Codec::new(3, 2)
  let payload = b"Independent chunks may cut through stripe and shard boundaries."
  let expected = try! @moonerasure.encode_object(
    codec,
    payload,
    77,
    stripe_payload_limit=11,
  )
  for width = 1; width <= payload.length(); width = width + 1 {
    let encoder = try! @moonerasure.ObjectEncoder::new(
      codec,
      77,
      payload.length(),
      stripe_payload_limit=11,
    )
    let frames : Array[@moonerasure.ShardEnvelope] = []
    let mut offset = 0
    while offset < payload.length() {
      let mut end = offset + width
      if end > payload.length() {
        end = payload.length()
      }
      let completed = try! encoder.push(
        Bytes::from_array(payload[offset:end].to_array()),
      )
      for frame in completed {
        frames.push(frame)
      }
      offset = end
    }
    assert_eq(
      (try! encoder.finish()).to_bytes(),
      expected.manifest().to_bytes(),
    )
    assert_eq(frames.length(), expected.frame_count())
    let reference = expected.frames()
    for index = 0; index < frames.length(); index = index + 1 {
      assert_eq(frames[index].to_bytes(), reference[index].to_bytes())
    }
  }
}

///|
test "incremental encoder rejects overrun without consuming it" {
  let codec = try! @moonerasure.Codec::new(2, 1)
  let encoder = try! @moonerasure.ObjectEncoder::new(
    codec,
    1,
    3,
    stripe_payload_limit=2,
  )
  let error = try encoder.push(b"four") catch {
    error => error.code()
  } noraise {
    _ => "unexpected success"
  }
  assert_eq(error, "ERASURE_RESOURCE_LIMIT")
  assert_eq(encoder.accepted_bytes(), 0)
  let frames = try! encoder.push(b"abc")
  assert_eq(frames.length(), 6)
  ignore(try! encoder.finish())
}

///|
test "incremental encoder detects underrun and supports empty object" {
  let codec = try! @moonerasure.Codec::new(2, 1)
  let short = try! @moonerasure.ObjectEncoder::new(codec, 1, 4)
  ignore(try! short.push(b"abc"))
  let error = try short.finish() catch {
    error => error.code()
  } noraise {
    _ => "unexpected success"
  }
  assert_eq(error, "ERASURE_MANIFEST")
  let empty = try! @moonerasure.ObjectEncoder::new(codec, 2, 0)
  assert_eq((try! empty.push(b"")).length(), 0)
  assert_eq((try! empty.finish()).stripe_count(), 0)
}
