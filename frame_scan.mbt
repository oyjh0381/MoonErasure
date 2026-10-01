///|
/// A rejected input frame is identified by its position in the input list.
/// The shard index inside a damaged header is deliberately not trusted.
pub struct FrameIssue {
  source_position : Int
  code : String
}

///|
pub fn FrameIssue::source_position(self : FrameIssue) -> Int {
  self.source_position
}

///|
pub fn FrameIssue::code(self : FrameIssue) -> String {
  self.code
}

///|
pub struct FrameScan {
  valid : Array[ShardEnvelope]
  issues : Array[FrameIssue]
}

///|
pub fn FrameScan::valid(self : FrameScan) -> Array[ShardEnvelope] {
  let result : Array[ShardEnvelope] = []
  for frame in self.valid {
    result.push(frame)
  }
  result
}

///|
pub fn FrameScan::issues(self : FrameScan) -> Array[FrameIssue] {
  let result : Array[FrameIssue] = []
  for issue in self.issues {
    result.push(issue)
  }
  result
}

///|
pub fn FrameScan::valid_count(self : FrameScan) -> Int {
  self.valid.length()
}

///|
pub fn FrameScan::rejected_count(self : FrameScan) -> Int {
  self.issues.length()
}

///|
/// Parse independent frames without discarding good neighbors. The caller must
/// still validate stripe identity and duplicates when using the valid frames.
pub fn scan_frames(
  inputs : Array[Bytes],
  max_frames? : Int = 4096,
  max_encoded_bytes? : Int = 16_777_216,
  max_total_bytes? : Int = 134_217_728,
) -> FrameScan raise ErasureError {
  if max_frames < 0 || max_frames > 1_048_576 || inputs.length() > max_frames {
    raise ResourceLimit("frame count exceeds scanner limit")
  }
  if max_total_bytes < 0 || max_total_bytes > 268_435_456 {
    raise InvalidConfiguration("scanner byte budget must be <= 256 MiB")
  }
  let valid : Array[ShardEnvelope] = []
  let issues : Array[FrameIssue] = []
  let mut used_bytes = 0
  for position = 0; position < inputs.length(); position = position + 1 {
    if inputs[position].length() > max_total_bytes - used_bytes {
      raise ResourceLimit("input frames exceed scanner byte budget")
    }
    used_bytes = used_bytes + inputs[position].length()
    let parsed = try ShardEnvelope::from_bytes(
      inputs[position],
      max_encoded_bytes~,
    ) catch {
      error => {
        issues.push({ source_position: position, code: error.code() })
        None
      }
    } noraise {
      frame => Some(frame)
    }
    match parsed {
      Some(frame) => valid.push(frame)
      None => ()
    }
  }
  { valid, issues }
}

///|
pub struct ScannedRecovery {
  recovery : StripeRecovery
  issues : Array[FrameIssue]
}

///|
pub fn ScannedRecovery::recovery(self : ScannedRecovery) -> StripeRecovery {
  self.recovery
}

///|
pub fn ScannedRecovery::issues(self : ScannedRecovery) -> Array[FrameIssue] {
  let result : Array[FrameIssue] = []
  for issue in self.issues {
    result.push(issue)
  }
  result
}

///|
/// Treat checksum-failed or malformed frames as erasures, while retaining a
/// diagnostic for each rejected input position. A sufficient set of valid
/// frames is still required.
pub fn recover_serialized_stripe(
  codec : Codec,
  inputs : Array[Bytes],
  set_id : Int,
  stripe_index : Int,
) -> ScannedRecovery raise ErasureError {
  let scan = scan_frames(
    inputs,
    max_frames=codec.total_count(),
    max_encoded_bytes=codec.max_encoded_bytes,
  )
  let recovery = recover_stripe(codec, scan.valid(), set_id, stripe_index)
  { recovery, issues: scan.issues() }
}
