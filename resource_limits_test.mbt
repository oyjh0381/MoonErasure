///|
test "codec rejects impossible dimensions before allocating matrices" {
  for dimensions in [(0, 1), (1, 0), (256, 1), (1, 256), (200, 57)] {
    let code = try @moonerasure.Codec::new(dimensions.0, dimensions.1) catch {
      error => error.code()
    } noraise {
      _ => "unexpected success"
    }
    assert_eq(code, "ERASURE_CONFIG")
  }
  let code = try @moonerasure.Codec::new(3, 2, max_encoded_bytes=4) catch {
    error => error.code()
  } noraise {
    _ => "unexpected success"
  }
  assert_eq(code, "ERASURE_CONFIG")
}

///|
test "object output budget is enforced at the exact frame boundary" {
  let codec = try! @moonerasure.Codec::new(3, 2)
  let object = try! @moonerasure.encode_object(
    codec,
    b"1234567890",
    1,
    stripe_payload_limit=10,
    max_output_bytes=180,
  )
  assert_eq(object.frame_count(), 5)
  let code = try @moonerasure.encode_object(
    codec,
    b"1234567890",
    1,
    stripe_payload_limit=10,
    max_output_bytes=179,
  ) catch {
    error => error.code()
  } noraise {
    _ => "unexpected success"
  }
  assert_eq(code, "ERASURE_RESOURCE_LIMIT")
}

///|
test "manifest accepts final stripe cap and rejects the next stripe" {
  let codec = try! @moonerasure.Codec::new(1, 1)
  let within = try! @moonerasure.Manifest::new(codec, 2, 1, 4096)
  assert_eq(within.stripe_count(), 4096)
  let code = try @moonerasure.Manifest::new(codec, 2, 1, 4097) catch {
    error => error.code()
  } noraise {
    _ => "unexpected success"
  }
  assert_eq(code, "ERASURE_RESOURCE_LIMIT")
}

///|
test "scanner refuses aggregate bytes before parsing corrupted input" {
  let codec = try! @moonerasure.Codec::new(2, 1)
  let frame = (try! @moonerasure.encode_stripe(codec, b"abc", 1, 0))[0]
  let wire = frame.to_bytes()
  let inputs : Array[Bytes] = [wire, wire]
  let code = try @moonerasure.scan_frames(
    inputs,
    max_total_bytes=wire.length() * 2 - 1,
  ) catch {
    error => error.code()
  } noraise {
    _ => "unexpected success"
  }
  assert_eq(code, "ERASURE_RESOURCE_LIMIT")
}

///|
test "incremental bundle parser enforces aggregate byte budget" {
  let codec = try! @moonerasure.Codec::new(2, 1)
  let object = try! @moonerasure.encode_object(codec, b"abc", 3)
  let wire = try! @moonerasure.export_bundle(object)
  let stream = try! @moonerasure.BundleStream::new(max_input_bytes=wire.length() - 1)
  let code = try stream.push(wire) catch {
    error => error.code()
  } noraise {
    _ => "unexpected success"
  }
  assert_eq(code, "ERASURE_RESOURCE_LIMIT")
  assert_eq(stream.parsed_frame_count(), 0)
}
