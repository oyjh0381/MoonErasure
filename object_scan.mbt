///|
/// Object recovery together with diagnostics for rejected raw frame positions.
pub struct ScannedObjectRecovery {
  recovery : ObjectRecovery
  issues : Array[FrameIssue]
}

///|
pub fn ScannedObjectRecovery::recovery(self : ScannedObjectRecovery) -> ObjectRecovery {
  self.recovery
}

///|
pub fn ScannedObjectRecovery::issues(self : ScannedObjectRecovery) -> Array[FrameIssue] {
  let copy : Array[FrameIssue] = []
  for issue in self.issues {
    copy.push(issue)
  }
  copy
}

///|
/// Recover an object from independently received shard frames. Corrupt or
/// malformed frames become known erasures; a mismatch among otherwise valid
/// frames is still rejected by stripe reconstruction.
pub fn recover_serialized_object(
  manifest : Manifest,
  inputs : Array[Bytes],
  max_encoded_bytes? : Int = 16_777_216,
  max_total_bytes? : Int = 134_217_728,
) -> ScannedObjectRecovery raise ErasureError {
  let total_slots = manifest.stripe_count() *
    (manifest.data_count() + manifest.parity_count())
  let scan = scan_frames(
    inputs,
    max_frames=total_slots,
    max_encoded_bytes~,
    max_total_bytes~,
  )
  let recovery = recover_object(manifest, scan.valid(), max_encoded_bytes~)
  { recovery, issues: scan.issues() }
}
