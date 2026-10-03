///|
/// Admit a batch atomically. Validate on a detached slot table, then publish
/// only after every identity and duplicate check succeeds. Frames are already
/// parsed; use add_bytes for CRC validation of external serialized frames.
pub fn FrameCatalog::add_many(
  self : FrameCatalog,
  frames : Array[ShardEnvelope],
  max_frames? : Int = 4096,
) -> Int raise ErasureError {
  if max_frames < 0 || frames.length() > max_frames {
    raise ResourceLimit("catalog batch frame count")
  }
  if frames.is_empty() {
    return 0
  }
  let staged : FrameCatalog = {
    manifest: self.manifest,
    slots: self.slots.copy(),
    stored_count: self.stored_count,
  }
  for frame in frames {
    staged.add(frame)
  }
  for index, slot in staged.slots {
    self.slots[index] = slot
  }
  self.stored_count = staged.stored_count
  frames.length()
}
