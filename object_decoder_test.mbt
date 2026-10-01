///|
test "sequential decoder emits one recovered stripe at a time" {
  let codec = try! @moonerasure.Codec::new(3, 2)
  let payload = b"Read and restore each stripe without buffering the whole object."
  let object = try! @moonerasure.encode_object(
    codec,
    payload,
    31,
    stripe_payload_limit=10,
  )
  let decoder = try! @moonerasure.ObjectDecoder::new(object.manifest())
  let output : Array[Byte] = []
  let frames = object.frames()
  for stripe_index = 0
      stripe_index < object.manifest().stripe_count()
      stripe_index = stripe_index + 1 {
    let group : Array[@moonerasure.ShardEnvelope] = []
    for frame in frames {
      if frame.stripe_index() == stripe_index &&
        frame.shard_index() != stripe_index % 5 {
        group.push(frame)
      }
    }
    let chunk = try! decoder.push_stripe(group)
    for byte in chunk {
      output.push(byte)
    }
  }
  assert_eq(Bytes::from_array(output), payload)
  assert_eq(try! decoder.finish(), object.manifest().stripe_count())
}

///|
test "sequential decoder retries the same stripe after insufficient frames" {
  let codec = try! @moonerasure.Codec::new(2, 1)
  let object = try! @moonerasure.encode_object(codec, b"abc", 4)
  let frames = object.frames()
  let insufficient : Array[@moonerasure.ShardEnvelope] = [frames[0]]
  let decoder = try! @moonerasure.ObjectDecoder::new(object.manifest())
  let failed = try decoder.push_stripe(insufficient) catch {
    error => error.code()
  } noraise {
    _ => "unexpected success"
  }
  assert_eq(failed, "ERASURE_NOT_ENOUGH_SHARDS")
  assert_eq(decoder.next_stripe(), 0)
  let enough : Array[@moonerasure.ShardEnvelope] = [frames[0], frames[2]]
  assert_eq(try! decoder.push_stripe(enough), b"abc")
  assert_eq(try! decoder.finish(), 1)
}
