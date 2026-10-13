///|
test "delta parity agrees with full encoding for every subset of changed data" {
  for k = 1; k <= 5; k = k + 1 {
    for m = 1; m <= 3; m = m + 1 {
      let codec = try! @moonerasure.Codec::new(k, m)
      let data : Array[Bytes] = []
      for index = 0; index < k; index = index + 1 {
        data.push(
          Bytes::from_array([(index * 17 + 1).to_byte(), b'\x00', b'\xff']),
        )
      }
      let parity = try! codec.encode(data)
      for mask = 0; mask < 1 << k; mask = mask + 1 {
        let changed : Array[Bytes] = []
        let updates : Array[@moonerasure.DataShardUpdate] = []
        for index = 0; index < k; index = index + 1 {
          if (mask & (1 << index)) != 0 {
            let replacement = Bytes::from_array([
              b'\xff',
              (index * 23).to_byte(),
              b'\x00',
            ])
            changed.push(replacement)
            updates.push({
              index,
              old_data: data[index],
              new_data: replacement,
            })
          } else {
            changed.push(data[index])
          }
        }
        assert_eq(
          try! codec.update_parity(parity, updates),
          try! codec.encode(changed),
        )
        assert_eq(parity, try! codec.encode(data))
      }
    }
  }
}

///|
test "delta updates compose and inverse updates restore the original parity" {
  let codec = try! @moonerasure.Codec::new(3, 2)
  let old = [b"abc", b"def", b"ghi"]
  let parity = try! codec.encode(old)
  let first : @moonerasure.DataShardUpdate = {
    index: 0,
    old_data: old[0],
    new_data: b"xyz",
  }
  let second : @moonerasure.DataShardUpdate = {
    index: 2,
    old_data: old[2],
    new_data: b"123",
  }
  let together = try! codec.update_parity(parity, [first, second])
  let staged = try! codec.update_parity(
    try! codec.update_parity(parity, [first]),
    [second],
  )
  assert_eq(together, staged)
  assert_eq(together, try! codec.encode([b"xyz", old[1], b"123"]))
  assert_eq(
    try! codec.update_parity(together, [
      { index: 0, old_data: b"xyz", new_data: old[0], },
      { index: 2, old_data: b"123", new_data: old[2], },
    ]),
    parity,
  )
}

///|
test "empty and equal updates preserve parity" {
  let codec = try! @moonerasure.Codec::new(2, 2)
  let data = [b"abc", b"def"]
  let parity = try! codec.encode(data)
  assert_eq(try! codec.update_parity(parity, []), parity)
  assert_eq(
    try! codec.update_parity(parity, [
      { index: 0, old_data: data[0], new_data: data[0], },
    ]),
    parity,
  )
}

///|
test "delta update validates old and new lengths before returning a result" {
  let codec = try! @moonerasure.Codec::new(2, 2)
  let parity = try! codec.encode([b"abc", b"def"])
  let malformed : Array[@moonerasure.DataShardUpdate] = [
    { index: 0, old_data: b"ab", new_data: b"xyz", },
    { index: 0, old_data: b"abc", new_data: b"xy", },
  ]
  for bad in malformed {
    let rejected = try codec.update_parity(parity, [bad]) catch {
      @moonerasure.InvalidShardLength(index=0, ..) => true
      _ => false
    } noraise {
      _ => false
    }
    assert_true(rejected)
  }
  assert_eq(parity, try! codec.encode([b"abc", b"def"]))
}

///|
test "delta update rejects invalid indices repeated replacements and parity shapes" {
  let codec = try! @moonerasure.Codec::new(2, 2)
  let parity = try! codec.encode([b"abc", b"def"])
  for index in [-1, 2, 2147483647] {
    let rejected = try
      codec.update_parity(parity, [
        { index, old_data: b"abc", new_data: b"xyz", },
      ])
    catch {
      @moonerasure.InvalidIndex(_) => true
      _ => false
    } noraise {
      _ => false
    }
    assert_true(rejected)
  }
  let update : @moonerasure.DataShardUpdate = {
    index: 1,
    old_data: b"def",
    new_data: b"xyz",
  }
  let duplicate = try codec.update_parity(parity, [update, update]) catch {
    @moonerasure.DuplicateIndex(1) => true
    _ => false
  } noraise {
    _ => false
  }
  assert_true(duplicate)
  let shape = try codec.update_parity([b"abc"], []) catch {
    @moonerasure.InvalidShardCount(..) => true
    _ => false
  } noraise {
    _ => false
  }
  assert_true(shape)
  let lengths = try codec.update_parity([b"abc", b"de"], []) catch {
    @moonerasure.InvalidShardLength(index=3, ..) => true
    _ => false
  } noraise {
    _ => false
  }
  assert_true(lengths)
}

///|
test "delta update respects shard resource limits and rejects empty parity" {
  let codec = try! @moonerasure.Codec::new(2, 2, max_encoded_bytes=8)
  let oversized = try codec.update_parity([b"abc", b"def"], []) catch {
    @moonerasure.ResourceLimit(_) => true
    _ => false
  } noraise {
    _ => false
  }
  assert_true(oversized)
  let empty = try codec.update_parity([b"", b""], []) catch {
    @moonerasure.EmptyShard => true
    _ => false
  } noraise {
    _ => false
  }
  assert_true(empty)
}
