///|
fn main raise {
  let codec = try! @lib.Codec::new(3, 2)
  let data = [b"page0000", b"metadata", b"journal0"]
  let parity = try! codec.encode(data)
  // Only two old and two replacement data bytes are provided, not a full page.
  let next = try! codec.update_parity_ranges(parity, [
    { index: 0, offset: 4, old_data: b"00", new_data: b"XY", },
  ])
  let changed = [b"pageXY00", data[1], data[2]]
  assert_eq(next, try! codec.encode(changed))
  assert_eq(parity, try! codec.encode(data))
  let available : Array[Bytes?] = [
    None,
    Some(changed[1]),
    Some(changed[2]),
    Some(next[0]),
    None,
  ]
  assert_eq(try! codec.reconstruct_selected(available, [0]), [changed[0]])
  assert_true(
    try {
      ignore(
        codec.update_parity_ranges(parity, [
          { index: 0, offset: 4, old_data: b"00", new_data: b"XY", },
          { index: 0, offset: 5, old_data: b"0", new_data: b"Z", },
        ]),
      )
      false
    } catch {
      _ => true
    },
  )
  println(
    "Range update: local byte patch matches full encoding; two-erasure recovery and overlap rejection passed",
  )
}
