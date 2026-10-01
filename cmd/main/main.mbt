///|
/// Runnable end-to-end example for backup storage with two parity shards.
fn main raise {
  let codec = try! @lib.Codec::new(3, 2)
  let input = b"A backup object distributed across independent storage locations."
  let object = try! @lib.encode_object(
    codec,
    input,
    20261001,
    stripe_payload_limit=16,
  )
  let retained : Array[@lib.ShardEnvelope] = []
  for frame in object.frames() {
    if frame.shard_index() != 1 && frame.shard_index() != 4 {
      retained.push(frame)
    }
  }
  let recovered = try! @lib.recover_object(object.manifest(), retained)
  assert_eq(recovered.payload(), input)
  let repair = try! @lib.repair_object(object.manifest(), retained)
  println("original bytes: " + input.length().to_string())
  println("stripes: " + recovered.stripe_count().to_string())
  println("replacement frames: " + repair.replacement_count().to_string())
  println("backup recovery: ok")
}
