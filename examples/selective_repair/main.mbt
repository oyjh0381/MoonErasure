///|
// A backup scrubber restores just the slots assigned to failed placements.
fn main raise {
  let codec = try! @lib.Codec::new(6, 3)
  let data : Array[Bytes] = []
  for index = 0; index < 6; index = index + 1 {
    let bytes = Array::make(2048, b'\x00')
    for position = 0; position < bytes.length(); position = position + 1 {
      bytes[position] = ((index * 43 + position * 7) % 256).to_byte()
    }
    data.push(Bytes::from_array(bytes))
  }
  let all = try! codec.encode_all(data)
  let storage : Array[Bytes?] = []
  let flags : Array[Bool] = []
  for index = 0; index < all.length(); index = index + 1 {
    let available = index != 0 && index != 2 && index != 8
    flags.push(available)
    storage.push(if available { Some(all[index]) } else { None })
  }
  let plan = try! codec.plan(flags)
  assert_true(plan.recoverable())
  assert_eq(plan.available(), 6)
  let slots = [8, 2, 0]
  let replacements = try! codec.reconstruct_selected(storage, slots)
  assert_eq(replacements, [all[8], all[2], all[0]])
  for position = 0; position < slots.length(); position = position + 1 {
    assert_eq(storage[slots[position]], None)
    storage[slots[position]] = Some(replacements[position])
  }
  let complete : Array[Bytes] = []
  for shard in storage {
    match shard {
      Some(bytes) => complete.push(bytes)
      None => abort("repair left a missing slot")
    }
  }
  assert_eq(complete, all)
  assert_true(try! codec.verify(complete))
  println("three-slot backup repair: verified")
  println("replacement output bytes: 6144; complete codeword bytes: 18432")
  println("only the three absent placements were replaced")
}
