///|
test "session reuses a matrix for repeated erasure patterns" {
  let codec = try! @moonerasure.Codec::new(4, 2)
  let session = try! @moonerasure.RecoverySession::new(codec)
  for seed = 0; seed < 5; seed = seed + 1 {
    let data : Array[Bytes] = []
    for index = 0; index < 4; index = index + 1 {
      let bytes = Array::make(23, b'\x00')
      for position = 0; position < bytes.length(); position = position + 1 {
        bytes[position] = ((seed * 13 + index * 31 + position * 17) % 256).to_byte()
      }
      data.push(Bytes::from_array(bytes))
    }
    let encoded = try! codec.encode_all(data)
    let erased : Array[Bytes?] = []
    for index = 0; index < encoded.length(); index = index + 1 {
      if index == 1 || index == 5 {
        erased.push(None)
      } else {
        erased.push(Some(encoded[index]))
      }
    }
    assert_eq(try! session.reconstruct(erased), encoded)
  }
  assert_eq(session.cache_size(), 1)
  assert_eq(session.cache_misses(), 1)
  assert_eq(session.cache_hits(), 4)
}

///|
test "session bounded cache evicts and still reconstructs correctly" {
  let codec = try! @moonerasure.Codec::new(3, 2)
  let session = try! @moonerasure.RecoverySession::new(codec, max_patterns=1)
  let data : Array[Bytes] = [b"abc", b"xyz", b"123"]
  let encoded = try! codec.encode_all(data)
  for lost in [0, 1, 0] {
    let shards : Array[Bytes?] = []
    for index = 0; index < encoded.length(); index = index + 1 {
      if index == lost {
        shards.push(None)
      } else {
        shards.push(Some(encoded[index]))
      }
    }
    assert_eq(try! session.reconstruct(shards), encoded)
  }
  assert_eq(session.cache_size(), 1)
  assert_eq(session.cache_misses(), 3)
  assert_eq(session.cache_hits(), 0)
}

///|
test "cached decoder still rejects an inconsistent extra shard" {
  let codec = try! @moonerasure.Codec::new(3, 2)
  let session = try! @moonerasure.RecoverySession::new(codec)
  let source : Array[Bytes] = [b"abc", b"def", b"ghi"]
  let encoded = try! codec.encode_all(source)
  let intact : Array[Bytes?] = []
  for index = 0; index < encoded.length(); index = index + 1 {
    if index == 0 {
      intact.push(None)
    } else {
      intact.push(Some(encoded[index]))
    }
  }
  assert_eq(try! session.reconstruct(intact), encoded)
  let inconsistent : Array[Bytes?] = []
  for index = 0; index < encoded.length(); index = index + 1 {
    if index == 0 {
      inconsistent.push(None)
    } else if index == 4 {
      inconsistent.push(Some(b"BAD"))
    } else {
      inconsistent.push(Some(encoded[index]))
    }
  }
  let code = try session.reconstruct(inconsistent) catch {
    error => error.code()
  } noraise {
    _ => "unexpected success"
  }
  assert_eq(code, "ERASURE_INCONSISTENT_SHARD")
  assert_eq(session.cache_hits(), 0)
  assert_eq(session.cache_misses(), 1)
}
