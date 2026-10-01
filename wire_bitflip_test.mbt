///|
test "every single bit flip in one frame fails parsing" {
  let codec = try! @moonerasure.Codec::new(3, 2)
  let frames = try! @moonerasure.encode_stripe(codec, b"payload", 14, 5)
  let wire = frames[0].to_bytes()
  for position = 0; position < wire.length(); position = position + 1 {
    for bit = 0; bit < 8; bit = bit + 1 {
      let damaged = wire.to_array()
      damaged[position] = (damaged[position].to_int() ^ (1 << bit)).to_byte()
      let accepted = try
        @moonerasure.ShardEnvelope::from_bytes(Bytes::from_array(damaged))
      catch {
        _ => false
      } noraise {
        _ => true
      }
      assert_true(!accepted)
    }
  }
}

///|
test "every single bit flip in a manifest fails parsing" {
  let codec = try! @moonerasure.Codec::new(3, 2)
  let manifest = try! @moonerasure.Manifest::new(codec, 15, 64, 219)
  let wire = manifest.to_bytes()
  for position = 0; position < wire.length(); position = position + 1 {
    for bit = 0; bit < 8; bit = bit + 1 {
      let damaged = wire.to_array()
      damaged[position] = (damaged[position].to_int() ^ (1 << bit)).to_byte()
      let accepted = try
        @moonerasure.Manifest::from_bytes(Bytes::from_array(damaged))
      catch {
        _ => false
      } noraise {
        _ => true
      }
      assert_true(!accepted)
    }
  }
}

///|
test "bundle import rejects every single bit flip in small archive" {
  let codec = try! @moonerasure.Codec::new(2, 1)
  let object = try! @moonerasure.encode_object(
    codec,
    b"archive",
    16,
    stripe_payload_limit=4,
  )
  let wire = try! @moonerasure.export_bundle(object)
  for position = 0; position < wire.length(); position = position + 1 {
    let damaged = wire.to_array()
    damaged[position] = (damaged[position].to_int() ^ 1).to_byte()
    let accepted = try
      @moonerasure.import_bundle(Bytes::from_array(damaged))
    catch {
      _ => false
    } noraise {
      _ => true
    }
    assert_true(!accepted)
  }
}
