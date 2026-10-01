///|
/// Health inspection of raw frames: invalid encodings are reported by input
/// position, while stripe status is computed from surviving valid frames.
pub struct ScannedObjectHealth {
  health : ObjectHealth
  issues : Array[FrameIssue]
}

///|
pub fn ScannedObjectHealth::health(self : ScannedObjectHealth) -> ObjectHealth {
  self.health
}

///|
pub fn ScannedObjectHealth::issues(
  self : ScannedObjectHealth,
) -> Array[FrameIssue] {
  let copy : Array[FrameIssue] = []
  for issue in self.issues {
    copy.push(issue)
  }
  copy
}

///|
/// Inspect an object directly from independently stored frame bytes.
/// A bad checksum is counted as missing capacity, but a valid frame with
/// conflicting set id, dimensions or duplicate slot marks input invalid.
pub fn inspect_serialized_object(
  manifest : Manifest,
  inputs : Array[Bytes],
  max_encoded_bytes? : Int = 16_777_216,
  max_total_bytes? : Int = 134_217_728,
) -> ScannedObjectHealth raise ErasureError {
  let total_slots = manifest.stripe_count() *
    (manifest.data_count() + manifest.parity_count())
  let scan = scan_frames(
    inputs,
    max_frames=total_slots,
    max_encoded_bytes~,
    max_total_bytes~,
  )
  let health = inspect_object(manifest, scan.valid(), max_encoded_bytes~)
  { health, issues: scan.issues(), }
}
