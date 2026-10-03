///|
/// A half-open byte range that has enough admitted frames to attempt recovery.
/// Presence is not authentication or a new content checksum verification.
pub struct RecoverableRange {
  start : Int
  end : Int
}

///|
pub fn RecoverableRange::start(self : RecoverableRange) -> Int {
  self.start
}

///|
pub fn RecoverableRange::end(self : RecoverableRange) -> Int {
  self.end
}

///|
pub fn RecoverableRange::length(self : RecoverableRange) -> Int {
  self.end - self.start
}

///|
/// Enumerate maximal contiguous ranges whose stripes each have at least k
/// admitted frames. Supports partial media reads and resume scheduling without
/// decoding the object. A result budget is checked before every emitted run.
pub fn FrameCatalog::recoverable_ranges(
  self : FrameCatalog,
  max_ranges? : Int = 4096,
) -> Array[RecoverableRange] raise ErasureError {
  if max_ranges < 0 {
    raise ResourceLimit("recoverable range count")
  }
  let width = self.manifest.data_count() + self.manifest.parity_count()
  let result : Array[RecoverableRange] = []
  let mut run_start : Int? = None
  for stripe = 0; stripe < self.manifest.stripe_count(); stripe = stripe + 1 {
    let mut present = 0
    for shard = 0; shard < width; shard = shard + 1 {
      if self.slots[stripe * width + shard] is Some(_) {
        present += 1
      }
    }
    let start = stripe * self.manifest.stripe_payload_limit()
    if present >= self.manifest.data_count() {
      if run_start is None {
        run_start = Some(start)
      }
    } else if run_start is Some(first) {
      if result.length() >= max_ranges {
        raise ResourceLimit("recoverable range count")
      }
      result.push({ start: first, end: start, })
      run_start = None
    }
  }
  if run_start is Some(first) {
    if result.length() >= max_ranges {
      raise ResourceLimit("recoverable range count")
    }
    result.push({ start: first, end: self.manifest.total_length(), })
  }
  result
}
