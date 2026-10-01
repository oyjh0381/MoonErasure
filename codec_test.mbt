///|
test "two missing data shards recover from parity" {
  let codec = try! @moonerasure.Codec::new(3, 2)
  let data = [b"alpha", b"bravo", b"charm"]
  let all = try! codec.encode_all(data)
  assert_true(try! codec.verify(all))
  let missing : Array[Bytes?] = [
    None,
    Some(all[1]),
    None,
    Some(all[3]),
    Some(all[4]),
  ]
  assert_eq(try! codec.reconstruct(missing), all)
}

///|
test "data remains readable and parity can be rebuilt" {
  let codec = try! @moonerasure.Codec::new(2, 2)
  let all = try! codec.encode_all([b"abc", b"def"])
  assert_eq(all[0], b"abc")
  assert_eq(all[1], b"def")
  let missing : Array[Bytes?] = [Some(all[0]), Some(all[1]), None, None]
  assert_eq(try! codec.reconstruct(missing), all)
}

///|
test "every sufficient subset reconstructs each small codeword" {
  for data_count = 1; data_count <= 4; data_count = data_count + 1 {
    for parity_count = 1; parity_count <= 3; parity_count = parity_count + 1 {
      let codec = try! @moonerasure.Codec::new(data_count, parity_count)
      let data : Array[Bytes] = []
      for index = 0; index < data_count; index = index + 1 {
        data.push(
          Bytes::from_array([
            (index * 37 + 9).to_byte(),
            (index * 53 + 17).to_byte(),
            (index * 71 + 23).to_byte(),
          ]),
        )
      }
      let encoded = try! codec.encode_all(data)
      for mask = 0; mask < (1 << codec.total_count()); mask = mask + 1 {
        let present : Array[Bytes?] = []
        let mut available = 0
        for index = 0; index < codec.total_count(); index = index + 1 {
          if (mask & (1 << index)) != 0 {
            present.push(Some(encoded[index]))
            available = available + 1
          } else {
            present.push(None)
          }
        }
        if available >= data_count {
          assert_eq(try! codec.reconstruct(present), encoded)
        }
      }
    }
  }
}

///|
test "invalid configuration and mismatched lengths are rejected" {
  let bad_config = try @moonerasure.Codec::new(0, 2) catch {
    @moonerasure.InvalidConfiguration(_) => true
    _ => false
  } noraise {
    _ => false
  }
  assert_true(bad_config)
  let overflow_config = try @moonerasure.Codec::new(2147483647, 2147483647) catch {
    @moonerasure.InvalidConfiguration(_) => true
    _ => false
  } noraise {
    _ => false
  }
  assert_true(overflow_config)
  let codec = try! @moonerasure.Codec::new(2, 1)
  let bad_length = try codec.encode([b"a", b"bb"]) catch {
    @moonerasure.InvalidShardLength(..) => true
    _ => false
  } noraise {
    _ => false
  }
  assert_true(bad_length)
  let shortage : Array[Bytes?] = [Some(b"a"), None, None]
  let not_enough = try codec.reconstruct(shortage) catch {
    @moonerasure.NotEnoughShards(..) => true
    _ => false
  } noraise {
    _ => false
  }
  assert_true(not_enough)
}

///|
test "extra inconsistent shard is detected" {
  let codec = try! @moonerasure.Codec::new(2, 2)
  let encoded = try! codec.encode_all([b"abc", b"def"])
  let inconsistent : Array[Bytes?] = [
    Some(encoded[0]),
    Some(encoded[1]),
    Some(b"xxx"),
    Some(encoded[3]),
  ]
  let rejected = try codec.reconstruct(inconsistent) catch {
    @moonerasure.InconsistentShard(_) => true
    _ => false
  } noraise {
    _ => false
  }
  assert_true(rejected)
}
