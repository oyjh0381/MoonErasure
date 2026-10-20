///|
test "range parity update agrees with full reencoding and preserves old inputs" {
  let c = try! @moonerasure.Codec::new(3, 2)
  let data = [b"abcdef", b"ghijkl", b"mnopqr"]
  let p = try! c.encode(data)
  let updates : Array[@moonerasure.DataRangeUpdate] = [
    { index: 0, offset: 4, old_data: b"ef", new_data: b"12", },
    { index: 2, offset: 1, old_data: b"no", new_data: b"XY", },
    { index: 0, offset: 0, old_data: b"ab", new_data: b"AB", },
  ]
  let next = try! c.update_parity_ranges(p, updates, max_changed_bytes=6)
  assert_eq(next, try! c.encode([b"ABcd12", b"ghijkl", b"mXYpqr"]))
  assert_eq(p, try! c.encode(data))
  assert_eq(try! c.update_parity_ranges(p, []), p)
  let slots : Array[Bytes?] = [
    None,
    Some(b"ghijkl"),
    Some(b"mXYpqr"),
    Some(next[0]),
    None,
  ]
  assert_eq(try! c.reconstruct_selected(slots, [0]), [b"ABcd12"])
}

///|
test "range parity accepts adjacent patches but rejects overlapping patches atomically" {
  let c = try! @moonerasure.Codec::new(1, 2)
  let p = try! c.encode([b"abcd"])
  let a : @moonerasure.DataRangeUpdate = {
    index: 0,
    offset: 0,
    old_data: b"ab",
    new_data: b"xy",
  }
  let b : @moonerasure.DataRangeUpdate = {
    index: 0,
    offset: 2,
    old_data: b"cd",
    new_data: b"zw",
  }
  assert_eq(try! c.update_parity_ranges(p, [b, a]), try! c.encode([b"xyzw"]))
  let overlap : @moonerasure.DataRangeUpdate = {
    index: 0,
    offset: 1,
    old_data: b"bc",
    new_data: b"zz",
  }
  assert_true(
    try {
      ignore(c.update_parity_ranges(p, [a, overlap]))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(c.update_parity_ranges(p, [a, a]))
      false
    } catch {
      _ => true
    },
  )
  assert_eq(p, try! c.encode([b"abcd"]))
}

///|
test "range updates validate boundaries shapes and budgets before calculation" {
  let c = try! @moonerasure.Codec::new(1, 1)
  let p = try! c.encode([b"abcd"])
  let good : @moonerasure.DataRangeUpdate = {
    index: 0,
    offset: 3,
    old_data: b"d",
    new_data: b"X",
  }
  assert_eq(
    try! c.update_parity_ranges(p, [good], max_ranges=1, max_changed_bytes=1),
    try! c.encode([b"abcX"]),
  )
  assert_true(
    try {
      ignore(c.update_parity_ranges(p, [good], max_ranges=0))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(c.update_parity_ranges(p, [good], max_changed_bytes=0))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(c.update_parity_ranges(p, [], max_ranges=-1))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(c.update_parity_ranges(p, [], max_changed_bytes=-1))
      false
    } catch {
      _ => true
    },
  )
  let bad : Array[@moonerasure.DataRangeUpdate] = [
    { index: 0, offset: 4, old_data: b"d", new_data: b"X", },
    { index: 0, offset: 2147483647, old_data: b"d", new_data: b"X", },
    { index: 0, offset: -1, old_data: b"d", new_data: b"X", },
    { index: 1, offset: 0, old_data: b"d", new_data: b"X", },
    { index: 0, offset: 0, old_data: b"", new_data: b"", },
    { index: 0, offset: 0, old_data: b"a", new_data: b"ab", },
  ]
  for patch in bad {
    assert_true(
      try {
        ignore(c.update_parity_ranges(p, [patch]))
        false
      } catch {
        _ => true
      },
    )
  }
  assert_true(
    try {
      ignore(c.update_parity_ranges([], []))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(c.update_parity_ranges([b""], []))
      false
    } catch {
      _ => true
    },
  )
}

///|
test "range parity differential sweep across codec dimensions offsets and zero deltas" {
  for k = 1; k <= 4; k = k + 1 {
    for m = 1; m <= 3; m = m + 1 {
      let c = try! @moonerasure.Codec::new(k, m)
      let data = Array::makei(k, fn(i) {
        Bytes::from_array(Array::makei(17, fn(j) { (i * 31 + j).to_byte() }))
      })
      let p = try! c.encode(data)
      for offset = 0; offset < 17; offset = offset + 1 {
        let updates : Array[@moonerasure.DataRangeUpdate] = []
        let next = data.copy()
        for index = 0; index < k; index = index + 1 {
          let new_byte = (index + offset * 7).to_byte()
          updates.push({
            index,
            offset,
            old_data: Bytes::from_array([data[index][offset]]),
            new_data: Bytes::from_array([new_byte]),
          })
          let changed = data[index].to_array()
          changed[offset] = new_byte
          next[index] = Bytes::from_array(changed)
        }
        assert_eq(try! c.update_parity_ranges(p, updates), try! c.encode(next))
      }
    }
  }
}
