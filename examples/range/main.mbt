///|
/// Only frames of stripes intersecting a requested byte range are fetched.
fn main raise {
  let codec = try! @lib.Codec::new(4, 2)
  let input = b"0123456789abcdefghijKLMNOPQRSTuvwxyz"
  let object = try! @lib.encode_object(
    codec,
    input,
    66,
    stripe_payload_limit=10,
  )
  let first = 8
  let length = 17
  let first_stripe = first / object.manifest().stripe_payload_limit()
  let last_stripe = (first + length - 1) /
    object.manifest().stripe_payload_limit()
  let fetched : Array[@lib.ShardEnvelope] = []
  for frame in object.frames() {
    if frame.stripe_index() >= first_stripe &&
      frame.stripe_index() <= last_stripe &&
      frame.shard_index() != 1 {
      fetched.push(frame)
    }
  }
  let slice = try! @lib.recover_object_range(
    object.manifest(),
    fetched,
    first,
    length,
  )
  assert_eq(slice, Bytes::from_array(input[first:first + length].to_array()))
  println("fetched frames: " + fetched.length().to_string())
  println("partial object read: ok")
}
