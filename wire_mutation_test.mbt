///|
test "every single-byte shard frame mutation is rejected" {
  let codec = try! @moonerasure.Codec::new(3, 2)
  let frames = try! @moonerasure.encode_stripe(
    codec, b"audit the entire wire frame", 11, 3,
  )
  let original = frames[4].to_bytes()
  for index = 0; index < original.length(); index = index + 1 {
    let changed = original.to_array()
    changed[index] = (changed[index].to_int() ^ 1).to_byte()
    let rejected = try
      @moonerasure.ShardEnvelope::from_bytes(Bytes::from_array(changed))
    catch {
      _ => true
    } noraise {
      _ => false
    }
    assert_true(rejected)
  }
}

///|
test "every single-byte manifest mutation is rejected" {
  let codec = try! @moonerasure.Codec::new(3, 2)
  let manifest = try! @moonerasure.Manifest::new(codec, 19, 100, 1000)
  let original = manifest.to_bytes()
  for index = 0; index < original.length(); index = index + 1 {
    let changed = original.to_array()
    changed[index] = (changed[index].to_int() ^ 1).to_byte()
    let rejected = try
      @moonerasure.Manifest::from_bytes(Bytes::from_array(changed))
    catch {
      _ => true
    } noraise {
      _ => false
    }
    assert_true(rejected)
  }
}

///|
test "single-byte bundle mutations are rejected" {
  let codec = try! @moonerasure.Codec::new(2, 1)
  let object = try! @moonerasure.encode_object(
    codec,
    b"a small but multi-stripe object",
    19,
    stripe_payload_limit=7,
  )
  let original = try! @moonerasure.export_bundle(object)
  for index = 0; index < original.length(); index = index + 1 {
    let changed = original.to_array()
    changed[index] = (changed[index].to_int() ^ 1).to_byte()
    let rejected = try
      @moonerasure.import_bundle(Bytes::from_array(changed))
    catch {
      _ => true
    } noraise {
      _ => false
    }
    assert_true(rejected)
  }
}
