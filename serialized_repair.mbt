///|
/// Repair result for raw frame inputs. Damaged frames are reported by input
/// position and treated as absent; replacement frames are checksum-protected.
pub struct ScannedObjectRepair {
  repair : ObjectRepair
  issues : Array[FrameIssue]
}

///|
pub fn ScannedObjectRepair::repair(self : ScannedObjectRepair) -> ObjectRepair {
  self.repair
}

///|
pub fn ScannedObjectRepair::issues(self : ScannedObjectRepair) -> Array[FrameIssue] {
  let copy : Array[FrameIssue] = []
  for issue in self.issues {
    copy.push(issue)
  }
  copy
}

///|
/// Scan independent serialized frames and regenerate every absent or damaged
/// slot. The returned issue positions let storage adapters quarantine bad
/// objects without trusting their internal shard indices.
pub fn repair_serialized_object(
  manifest : Manifest,
  inputs : Array[Bytes],
  max_encoded_bytes? : Int = 16_777_216,
  max_total_bytes? : Int = 134_217_728,
) -> ScannedObjectRepair raise ErasureError {
  let total_slots = manifest.stripe_count() *
    (manifest.data_count() + manifest.parity_count())
  let scan = scan_frames(
    inputs,
    max_frames=total_slots,
    max_encoded_bytes~,
    max_total_bytes~,
  )
  let repair = repair_object(manifest, scan.valid(), max_encoded_bytes~)
  { repair, issues: scan.issues() }
}
