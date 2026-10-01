///|
/// Feed an object in arbitrary chunks, then consume its stripes sequentially.
fn main raise {
  let payload = b"A long upload can be encoded and decoded stripe by stripe."
  let codec = try! @lib.Codec::new(3, 2)
  let encoder = try! @lib.ObjectEncoder::new(
    codec,
    91,
    payload.length(),
    stripe_payload_limit=9,
  )
  let saved : Array[@lib.ShardEnvelope] = []
  let mut offset = 0
  while offset < payload.length() {
    let mut end = offset + 4
    if end > payload.length() {
      end = payload.length()
    }
    let new_frames = try! encoder.push(
      Bytes::from_array(payload[offset:end].to_array()),
    )
    for frame in new_frames {
      saved.push(frame)
    }
    offset = end
  }
  let manifest = try! encoder.finish()
  let decoder = try! @lib.ObjectDecoder::new(manifest)
  let output : Array[Byte] = []
  for stripe = 0; stripe < manifest.stripe_count(); stripe = stripe + 1 {
    let received : Array[@lib.ShardEnvelope] = []
    for frame in saved {
      if frame.stripe_index() == stripe && frame.shard_index() != 0 {
        received.push(frame)
      }
    }
    let chunk = try! decoder.push_stripe(received)
    for byte in chunk {
      output.push(byte)
    }
  }
  ignore(try! decoder.finish())
  assert_eq(Bytes::from_array(output), payload)
  println("streamed stripes: " + manifest.stripe_count().to_string())
  println("incremental round trip: ok")
}
