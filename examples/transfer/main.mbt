///|
/// Independent serialized packets can arrive unordered and some can fail CRC.
fn main raise {
  let codec = try! @lib.Codec::new(4, 2)
  let original = b"Network packet groups may arrive out of order or be lost."
  let object = try! @lib.encode_object(
    codec,
    original,
    81,
    stripe_payload_limit=13,
  )
  let frames = object.frames()
  let received : Array[Bytes] = []
  for index = frames.length() - 1; index >= 0; index = index - 1 {
    let frame = frames[index]
    if frame.shard_index() != 0 {
      let packet = frame.to_bytes()
      if frame.shard_index() == 5 {
        let damaged = packet.to_array()
        damaged[damaged.length() - 1] = (
          damaged[damaged.length() - 1].to_int() ^ 1
        ).to_byte()
        received.push(Bytes::from_array(damaged))
      } else {
        received.push(packet)
      }
    }
  }
  let result = try! @lib.recover_serialized_object(object.manifest(), received)
  assert_eq(result.recovery().payload(), original)
  println("rejected damaged packets: " + result.issues().length().to_string())
  println("recovered bytes: " + result.recovery().payload().length().to_string())
  println("packet transfer recovery: ok")
}
