///|
// A block store updates one 4 KiB block in a 10+4 stripe.
fn main raise {
  let codec = try! @lib.Codec::new(10, 4)
  let data : Array[Bytes] = []
  for index = 0; index < 10; index = index + 1 {
    let bytes = Array::make(4096, b'\x00')
    for position = 0; position < bytes.length(); position = position + 1 {
      bytes[position] = ((index * 37 + position * 11) % 256).to_byte()
    }
    data.push(Bytes::from_array(bytes))
  }
  let original_parity = try! codec.encode(data)
  let replacement = Bytes::from_array(Array::make(4096, b'\x5a'))
  let updates : Array[@lib.DataShardUpdate] = [
    { index: 3, old_data: data[3], new_data: replacement, },
  ]
  // The update call receives no other data blocks.
  let next_parity = try! codec.update_parity(original_parity, updates)
  let next_data = data.copy()
  next_data[3] = replacement
  assert_eq(next_parity, try! codec.encode(next_data))
  assert_eq(original_parity, try! codec.encode(data))
  // Model a generation commit: all new data/parity become visible together.
  let committed = next_data.copy()
  for parity in next_parity {
    committed.push(parity)
  }
  assert_true(try! codec.verify(committed))
  let surviving : Array[Bytes?] = []
  for index = 0; index < committed.length(); index = index + 1 {
    if index == 3 || index == 11 || index == 12 || index == 13 {
      surviving.push(None)
    } else {
      surviving.push(Some(committed[index]))
    }
  }
  assert_eq(try! codec.reconstruct_selected(surviving, [3]), [replacement])
  println("one-block update and subsequent four-erasure read: verified")
  println("update input bytes: 24576; complete encode data input bytes: 40960")
  println("unchanged data blocks read by update_parity: 0")
  println(
    "I/O and generation persistence are the host adapter's responsibility",
  )
}
