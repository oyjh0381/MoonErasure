///|
/// A storage scrubber inventories missing slots, verifies recoverability and
/// reconstructs replacement frame bytes for the caller to persist.
fn main raise {
  let codec = try! @lib.Codec::new(3, 2)
  let object = try! @lib.encode_object(
    codec,
    b"A scrubber checks object health before choosing repair work.",
    55,
    stripe_payload_limit=12,
  )
  let catalog = @lib.FrameCatalog::new(object.manifest())
  for frame in object.frames() {
    if frame.shard_index() != 2 {
      try! catalog.add(frame)
    }
  }
  let present : Array[@lib.ShardEnvelope] = []
  for index = 0; index < object.manifest().stripe_count(); index = index + 1 {
    let group = try! catalog.stripe_frames(index)
    for frame in group {
      present.push(frame)
    }
  }
  let health = try! @lib.inspect_object(object.manifest(), present)
  assert_true(health.fully_recoverable())
  println("repairable stripes: " + health.repairable_count().to_string())
  for index = 0; index < object.manifest().stripe_count(); index = index + 1 {
    let recovery = try! catalog.recover_stripe(index)
    let rebuilt = recovery.shards()
    for missing in recovery.missing_indices() {
      let replacement = rebuilt[missing]
      try! catalog.add(replacement)
    }
  }
  assert_eq(catalog.stored_count(), catalog.capacity())
  println("scrub and repair: ok")
}
