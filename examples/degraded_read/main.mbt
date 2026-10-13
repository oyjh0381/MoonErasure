///|
// A storage adapter has six verified surviving blocks and needs one data block.
fn main raise {
  let codec = try! @lib.Codec::new(6, 3)
  let data : Array[Bytes] = []
  for index = 0; index < 6; index = index + 1 {
    let bytes = Array::make(4096, b'\x00')
    for position = 0; position < bytes.length(); position = position + 1 {
      bytes[position] = ((index * 29 + position * 17) % 256).to_byte()
    }
    data.push(Bytes::from_array(bytes))
  }
  let encoded = try! codec.encode_all(data)
  let surviving : Array[Bytes?] = []
  for index = 0; index < encoded.length(); index = index + 1 {
    if index == 1 || index == 7 || index == 8 {
      surviving.push(None)
    } else {
      surviving.push(Some(encoded[index]))
    }
  }
  let wanted = try! codec.reconstruct_selected(surviving, [1])
  assert_eq(wanted, [data[1]])
  assert_eq(surviving[1], None)
  assert_eq(surviving[7], None)
  assert_eq(surviving[8], None)
  assert_eq(wanted[0].length(), 4096)
  println("degraded block read: verified")
  println("selected output bytes: 4096; full codeword output bytes: 36864")
  println(
    "known-intact input blocks required: 6; unrequested erased slots remain absent",
  )
}
