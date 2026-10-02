///|
/// In-memory index for independently stored frames of one manifest. A
/// storage adapter may use it to decide which stripe to fetch or repair.
pub struct FrameCatalog {
  manifest : Manifest
  slots : Array[ShardEnvelope?]
  mut stored_count : Int
}

///|
pub fn FrameCatalog::new(manifest : Manifest) -> FrameCatalog {
  let total_slots = manifest.stripe_count() *
    (manifest.data_count() + manifest.parity_count())
  { manifest, slots: Array::make(total_slots, None), stored_count: 0, }
}

///|
pub fn FrameCatalog::manifest(self : FrameCatalog) -> Manifest {
  self.manifest
}

///|
pub fn FrameCatalog::stored_count(self : FrameCatalog) -> Int {
  self.stored_count
}

///|
pub fn FrameCatalog::capacity(self : FrameCatalog) -> Int {
  self.slots.length()
}

///|
fn FrameCatalog::slot_index(
  self : FrameCatalog,
  stripe_index : Int,
  shard_index : Int,
) -> Int raise ErasureError {
  if stripe_index < 0 || stripe_index >= self.manifest.stripe_count() {
    raise InvalidIndex(stripe_index)
  }
  let width = self.manifest.data_count() + self.manifest.parity_count()
  if shard_index < 0 || shard_index >= width {
    raise InvalidIndex(shard_index)
  }
  stripe_index * width + shard_index
}

///|
/// Register one already parsed frame. Identity, dimensions, original stripe
/// length and duplicate index are checked before the catalog changes.
pub fn FrameCatalog::add(
  self : FrameCatalog,
  frame : ShardEnvelope,
) -> Unit raise ErasureError {
  if frame.set_id() != self.manifest.set_id() ||
    frame.data_count() != self.manifest.data_count() ||
    frame.parity_count() != self.manifest.parity_count() {
    raise InvalidEnvelope("catalog frame identity or dimensions differ")
  }
  let stripe_index = frame.stripe_index()
  let slot = self.slot_index(stripe_index, frame.shard_index())
  if frame.original_length() != self.manifest.stripe_length(stripe_index) {
    raise InvalidEnvelope("catalog frame stripe length differs")
  }
  if self.slots[slot] is Some(_) {
    raise DuplicateIndex(frame.shard_index())
  }
  self.slots[slot] = Some(frame)
  self.stored_count = self.stored_count + 1
}

///|
/// Look up one slot. A missing slot is returned as None.
pub fn FrameCatalog::get(
  self : FrameCatalog,
  stripe_index : Int,
  shard_index : Int,
) -> ShardEnvelope? raise ErasureError {
  self.slots[self.slot_index(stripe_index, shard_index)]
}

///|
/// Evict a slot after a storage read or checksum check shows that its bytes
/// can no longer be trusted. Removing an absent slot is a harmless no-op.
pub fn FrameCatalog::invalidate(
  self : FrameCatalog,
  stripe_index : Int,
  shard_index : Int,
) -> Bool raise ErasureError {
  let slot = self.slot_index(stripe_index, shard_index)
  if self.slots[slot] is None {
    return false
  }
  self.slots[slot] = None
  self.stored_count = self.stored_count - 1
  true
}

///|
/// Parse a serialized frame and admit it only if both its CRC and catalog
/// identity checks pass. A failed call leaves the catalog unchanged.
pub fn FrameCatalog::add_bytes(
  self : FrameCatalog,
  wire : Bytes,
  max_encoded_bytes? : Int = 16_777_216,
) -> Unit raise ErasureError {
  let frame = ShardEnvelope::from_bytes(wire, max_encoded_bytes~)
  self.add(frame)
}

///|
/// Return present frames of a stripe in canonical shard index order.
pub fn FrameCatalog::stripe_frames(
  self : FrameCatalog,
  stripe_index : Int,
) -> Array[ShardEnvelope] raise ErasureError {
  let width = self.manifest.data_count() + self.manifest.parity_count()
  ignore(self.slot_index(stripe_index, 0))
  let frames : Array[ShardEnvelope] = []
  for index = 0; index < width; index = index + 1 {
    match self.slots[stripe_index * width + index] {
      Some(frame) => frames.push(frame)
      None => ()
    }
  }
  frames
}

///|
/// Return the missing shard indices of a stripe in ascending order.
pub fn FrameCatalog::missing_indices(
  self : FrameCatalog,
  stripe_index : Int,
) -> Array[Int] raise ErasureError {
  let width = self.manifest.data_count() + self.manifest.parity_count()
  ignore(self.slot_index(stripe_index, 0))
  let missing : Array[Int] = []
  for index = 0; index < width; index = index + 1 {
    if self.slots[stripe_index * width + index] is None {
      missing.push(index)
    }
  }
  missing
}

///|
pub fn FrameCatalog::stripe_recoverable(
  self : FrameCatalog,
  stripe_index : Int,
) -> Bool raise ErasureError {
  let width = self.manifest.data_count() + self.manifest.parity_count()
  let missing = self.missing_indices(stripe_index)
  width - missing.length() >= self.manifest.data_count()
}

///|
/// Decode an indexed stripe. Present bytes are still cross-checked by
/// `recover_stripe`, since catalog admission validates metadata only.
pub fn FrameCatalog::recover_stripe(
  self : FrameCatalog,
  stripe_index : Int,
  max_encoded_bytes? : Int = 16_777_216,
) -> StripeRecovery raise ErasureError {
  let codec = Codec::new(
    self.manifest.data_count(),
    self.manifest.parity_count(),
    max_encoded_bytes~,
  )
  if self.manifest.stripe_payload_limit() >
    codec.data_count() * codec.max_shard_bytes() {
    raise ResourceLimit("codec budget cannot hold manifest stripe")
  }
  let recovery = recover_stripe(
    codec,
    self.stripe_frames(stripe_index),
    self.manifest.set_id(),
    stripe_index,
  )
  if recovery.payload().length() != self.manifest.stripe_length(stripe_index) {
    raise InvalidManifest("catalog recovered length differs from manifest")
  }
  recovery
}

///|
/// Decode only the stripes intersecting a requested range from indexed
/// frames. This is useful after an application has inventoried unordered
/// stored fragments but needs a small portion of the original object.
pub fn FrameCatalog::recover_range(
  self : FrameCatalog,
  start : Int,
  length : Int,
  max_encoded_bytes? : Int = 16_777_216,
) -> Bytes raise ErasureError {
  if start < 0 ||
    length < 0 ||
    start > self.manifest.total_length() ||
    length > self.manifest.total_length() - start {
    raise InvalidRange
  }
  if length == 0 {
    return b""
  }
  let first = start / self.manifest.stripe_payload_limit()
  let last = (start + length - 1) / self.manifest.stripe_payload_limit()
  let selected : Array[ShardEnvelope] = []
  for stripe = first; stripe <= last; stripe = stripe + 1 {
    let group = self.stripe_frames(stripe)
    for frame in group {
      selected.push(frame)
    }
  }
  recover_object_range(
    self.manifest,
    selected,
    start,
    length,
    max_encoded_bytes~,
  )
}
