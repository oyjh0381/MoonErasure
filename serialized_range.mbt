///|
/// A recovered byte range and diagnostics for raw frames rejected by CRC or
/// structural validation.
pub struct ScannedRangeRecovery {
  payload : Bytes
  issues : Array[FrameIssue]
}

///|
pub fn ScannedRangeRecovery::payload(self : ScannedRangeRecovery) -> Bytes {
  copy_shard(self.payload)
}

///|
pub fn ScannedRangeRecovery::issues(self : ScannedRangeRecovery) -> Array[FrameIssue] {
  let copy : Array[FrameIssue] = []
  for issue in self.issues {
    copy.push(issue)
  }
  copy
}

///|
/// Recover an object byte range from independently stored serialized frames.
/// Only intersecting stripes are decoded. Damaged frames within those stripes
/// are erasures and must fit the parity budget.
pub fn recover_serialized_range(
  manifest : Manifest,
  inputs : Array[Bytes],
  start : Int,
  length : Int,
  max_encoded_bytes? : Int = 16_777_216,
  max_total_bytes? : Int = 134_217_728,
) -> ScannedRangeRecovery raise ErasureError {
  if start < 0 || length < 0 || start > manifest.total_length() ||
    length > manifest.total_length() - start {
    raise InvalidRange
  }
  let total_slots = manifest.stripe_count() *
    (manifest.data_count() + manifest.parity_count())
  let scan = scan_frames(
    inputs,
    max_frames=total_slots,
    max_encoded_bytes~,
    max_total_bytes~,
  )
  let payload = recover_object_range(
    manifest,
    scan.valid(),
    start,
    length,
    max_encoded_bytes~,
  )
  { payload, issues: scan.issues() }
}
