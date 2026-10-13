///|
test "selected recovery agrees with full codewords for every small erasure pattern" {
  for k = 1; k <= 4; k = k + 1 {
    for m = 1; m <= 3; m = m + 1 {
      let codec = try! @moonerasure.Codec::new(k, m)
      let data : Array[Bytes] = []
      for index = 0; index < k; index = index + 1 {
        data.push(
          Bytes::from_array([
            (index * 41).to_byte(),
            (index * 53 + 7).to_byte(),
            b'\xff',
          ]),
        )
      }
      let all = try! codec.encode_all(data)
      for mask = 0; mask < 1 << (k + m); mask = mask + 1 {
        let input : Array[Bytes?] = []
        let mut available = 0
        for index = 0; index < k + m; index = index + 1 {
          if (mask & (1 << index)) != 0 {
            input.push(Some(all[index]))
            available = available + 1
          } else {
            input.push(None)
          }
        }
        if available >= k {
          for index = 0; index < k + m; index = index + 1 {
            assert_eq(try! codec.reconstruct_selected(input, [index]), [
              all[index],
            ])
          }
          assert_eq(try! codec.reconstruct_selected(input, [k + m - 1, 0]), [
            all[k + m - 1],
            all[0],
          ])
        }
      }
    }
  }
}

///|
test "selected recovery supports absent parity and leaves unrequested slots missing" {
  let codec = try! @moonerasure.Codec::new(3, 3)
  let all = try! codec.encode_all([b"abc", b"def", b"ghi"])
  let input : Array[Bytes?] = [
    None,
    Some(all[1]),
    None,
    Some(all[3]),
    Some(all[4]),
    None,
  ]
  let result = try! codec.reconstruct_selected(input, [5, 0])
  assert_eq(result, [all[5], all[0]])
  assert_eq(input[0], None)
  assert_eq(input[2], None)
  assert_eq(input[5], None)
}

///|
test "selected recovery rejects inconsistent surplus evidence" {
  let codec = try! @moonerasure.Codec::new(3, 2)
  let all = try! codec.encode_all([b"abc", b"def", b"ghi"])
  let input : Array[Bytes?] = [
    Some(all[0]),
    Some(all[1]),
    Some(all[2]),
    Some(b"bad"),
    None,
  ]
  let rejected = try codec.reconstruct_selected(input, [4]) catch {
    @moonerasure.InconsistentShard(3) => true
    _ => false
  } noraise {
    _ => false
  }
  assert_true(rejected)
}

///|
test "selected recovery rejects inconsistent extra data with parity in basis" {
  let codec = try! @moonerasure.Codec::new(2, 3)
  let all = try! codec.encode_all([b"abc", b"def"])
  let input : Array[Bytes?] = [
    None,
    Some(all[1]),
    Some(all[2]),
    Some(all[3]),
    Some(b"bad"),
  ]
  let rejected = try codec.reconstruct_selected(input, [0]) catch {
    @moonerasure.InconsistentShard(4) => true
    _ => false
  } noraise {
    _ => false
  }
  assert_true(rejected)
}

///|
test "selected recovery validates indices duplicates and input shapes" {
  let codec = try! @moonerasure.Codec::new(2, 2)
  let all = try! codec.encode_all([b"abc", b"def"])
  let input : Array[Bytes?] = [Some(all[0]), Some(all[1]), None, None]
  for index in [-1, 4, 2147483647] {
    let rejected = try codec.reconstruct_selected(input, [index]) catch {
      @moonerasure.InvalidIndex(_) => true
      _ => false
    } noraise {
      _ => false
    }
    assert_true(rejected)
  }
  let duplicate = try codec.reconstruct_selected(input, [1, 1]) catch {
    @moonerasure.DuplicateIndex(1) => true
    _ => false
  } noraise {
    _ => false
  }
  assert_true(duplicate)
  let wrong_shape = try codec.reconstruct_selected([Some(b"a")], []) catch {
    @moonerasure.InvalidShardCount(..) => true
    _ => false
  } noraise {
    _ => false
  }
  assert_true(wrong_shape)
  let wrong_length = try
    codec.reconstruct_selected([Some(b"a"), Some(b"bb"), None, None], [2])
  catch {
    @moonerasure.InvalidShardLength(index=1, ..) => true
    _ => false
  } noraise {
    _ => false
  }
  assert_true(wrong_length)
}

///|
test "empty selection and unrecoverable selection have distinct contracts" {
  let codec = try! @moonerasure.Codec::new(2, 2)
  let absent : Array[Bytes?] = [None, None, None, None]
  assert_eq(try! codec.reconstruct_selected(absent, []), [])
  let shortage = try codec.reconstruct_selected(absent, [0]) catch {
    @moonerasure.NotEnoughShards(required=2, available=0) => true
    _ => false
  } noraise {
    _ => false
  }
  assert_true(shortage)
  let bounded = try! @moonerasure.Codec::new(2, 2, max_encoded_bytes=8)
  let oversized = try
    bounded.reconstruct_selected([Some(b"abc"), Some(b"def"), None, None], [2])
  catch {
    @moonerasure.ResourceLimit(_) => true
    _ => false
  } noraise {
    _ => false
  }
  assert_true(oversized)
  let empty = try
    codec.reconstruct_selected([Some(b""), None, None, None], [])
  catch {
    @moonerasure.EmptyShard => true
    _ => false
  } noraise {
    _ => false
  }
  assert_true(empty)
}
