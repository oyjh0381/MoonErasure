///|
test "stripe roundtrip with two erased frames and padding" {
  let codec = try! @moonerasure.Codec::new(3, 2)
  let frames = try! @moonerasure.encode_stripe(codec, b"hello, moonbit", 17, 4)
  assert_eq(frames.length(), 5)
  let remaining = [frames[0], frames[2], frames[4]]
  let result = try! @moonerasure.recover_stripe(codec, remaining, 17, 4)
  assert_eq(result.payload(), b"hello, moonbit")
  assert_eq(result.missing_indices(), [1, 3])
  assert_eq(result.provided_count(), 3)
  assert_eq(result.shards().length(), 5)
  for index = 0; index < frames.length(); index = index + 1 {
    assert_eq(result.shards()[index].to_bytes(), frames[index].to_bytes())
  }
}

///|
test "stripe rejects duplicate and mixed frames" {
  let codec = try! @moonerasure.Codec::new(2, 1)
  let first = try! @moonerasure.encode_stripe(codec, b"abcd", 1, 0)
  let other = try! @moonerasure.encode_stripe(codec, b"abcd", 2, 0)
  let duplicate = try
    @moonerasure.recover_stripe(codec, [first[0], first[0]], 1, 0)
  catch {
    @moonerasure.DuplicateIndex(_) => true
    _ => false
  } noraise {
    _ => false
  }
  assert_true(duplicate)
  let mixed = try
    @moonerasure.recover_stripe(codec, [first[0], other[1]], 1, 0)
  catch {
    @moonerasure.InvalidEnvelope(_) => true
    _ => false
  } noraise {
    _ => false
  }
  assert_true(mixed)
}

///|
test "stripe rejects a noncanonical nonzero padding tail" {
  let codec = try! @moonerasure.Codec::new(2, 1)
  let encoded = try! codec.encode_all([b"ab", b"cx"])
  let frames : Array[@moonerasure.ShardEnvelope] = []
  for index = 0; index < encoded.length(); index = index + 1 {
    frames.push(
      try! @moonerasure.ShardEnvelope::new(
        codec,
        3,
        0,
        index,
        3,
        encoded[index],
      ),
    )
  }
  let rejected = try @moonerasure.recover_stripe(codec, frames, 3, 0) catch {
    @moonerasure.InvalidEnvelope(_) => true
    _ => false
  } noraise {
    _ => false
  }
  assert_true(rejected)
}
