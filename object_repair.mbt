///|
/// Replacement frames for missing slots, in stripe then shard order.
/// The caller decides where to persist them. Existing frames are never rewritten.
pub struct ObjectRepair {
  replacements : Array[ShardEnvelope]
  repaired_stripes : Int
}

///|
pub fn ObjectRepair::replacements(self : ObjectRepair) -> Array[ShardEnvelope] {
  let copy : Array[ShardEnvelope] = []
  for frame in self.replacements {
    copy.push(frame)
  }
  copy
}

///|
pub fn ObjectRepair::replacement_count(self : ObjectRepair) -> Int {
  self.replacements.length()
}

///|
pub fn ObjectRepair::repaired_stripes(self : ObjectRepair) -> Int {
  self.repaired_stripes
}

///|
/// Regenerate only absent frames. Every supplied frame is checked by the
/// stripe decoder; missing frames beyond parity capacity abort the operation.
/// This operation is all-or-error: callers receive no partial repair list.
pub fn repair_object(
  manifest : Manifest,
  frames : Array[ShardEnvelope],
  max_encoded_bytes? : Int = 16_777_216,
) -> ObjectRepair raise ErasureError {
  let codec = Codec::new(
    manifest.data_count(),
    manifest.parity_count(),
    max_encoded_bytes~,
  )
  if manifest.stripe_payload_limit() > codec.data_count() * codec.max_shard_bytes() {
    raise ResourceLimit("codec budget cannot hold manifest stripe")
  }
  if frames.length() > manifest.stripe_count() * codec.total_count() {
    raise ResourceLimit("too many frames for manifest")
  }
  let groups : Array[Array[ShardEnvelope]] = []
  for index = 0; index < manifest.stripe_count(); index = index + 1 {
    groups.push([])
  }
  for frame in frames {
    if frame.set_id() != manifest.set_id() {
      raise InvalidManifest("repair frame set id differs from manifest")
    }
    let stripe_index = frame.stripe_index()
    if stripe_index < 0 || stripe_index >= manifest.stripe_count() {
      raise InvalidIndex(stripe_index)
    }
    groups[stripe_index].push(frame)
  }
  let replacements : Array[ShardEnvelope] = []
  let mut repaired_stripes = 0
  for index = 0; index < manifest.stripe_count(); index = index + 1 {
    let result = recover_stripe(codec, groups[index], manifest.set_id(), index)
    if result.payload().length() != manifest.stripe_length(index) {
      raise InvalidManifest("repair stripe length differs from manifest")
    }
    let missing = result.missing_indices()
    if missing.length() > 0 {
      repaired_stripes = repaired_stripes + 1
      let rebuilt = result.shards()
      for shard_index in missing {
        replacements.push(rebuilt[shard_index])
      }
    }
  }
  { replacements, repaired_stripes }
}
