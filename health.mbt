///|
/// Result of examining one stripe without returning payload bytes.
pub(all) enum StripeStatus {
  Healthy
  Repairable
  Unrecoverable
  InvalidInput
}

///|
pub fn StripeStatus::label(self : StripeStatus) -> String {
  match self {
    Healthy => "healthy"
    Repairable => "repairable"
    Unrecoverable => "unrecoverable"
    InvalidInput => "invalid-input"
  }
}

///|
pub struct StripeHealth {
  stripe_index : Int
  status : StripeStatus
  present_count : Int
  missing_indices : Array[Int]
  reason_code : String?
}

///|
pub fn StripeHealth::stripe_index(self : StripeHealth) -> Int {
  self.stripe_index
}

///|
pub fn StripeHealth::status(self : StripeHealth) -> StripeStatus {
  self.status
}

///|
pub fn StripeHealth::present_count(self : StripeHealth) -> Int {
  self.present_count
}

///|
pub fn StripeHealth::missing_indices(self : StripeHealth) -> Array[Int] {
  let copy : Array[Int] = []
  for index in self.missing_indices {
    copy.push(index)
  }
  copy
}

///|
pub fn StripeHealth::reason_code(self : StripeHealth) -> String? {
  self.reason_code
}

///|
fn invalid_health(
  stripe_index : Int,
  present_count : Int,
  missing_indices : Array[Int],
  reason_code : String,
) -> StripeHealth {
  {
    stripe_index,
    status: InvalidInput,
    present_count,
    missing_indices,
    reason_code: Some(reason_code),
  }
}

///|
/// Plan an individual stripe and verify consistency when enough frames exist.
pub fn inspect_stripe(
  codec : Codec,
  frames : Array[ShardEnvelope],
  set_id : Int,
  stripe_index : Int,
) -> StripeHealth {
  let present = Array::make(codec.total_count(), false)
  let mut reason_code : String? = None
  let mut present_count = 0
  for frame in frames {
    let index = frame.shard_index()
    if frame.set_id() != set_id ||
      frame.stripe_index() != stripe_index ||
      frame.data_count() != codec.data_count() ||
      frame.parity_count() != codec.parity_count() {
      reason_code = Some("ERASURE_ENVELOPE")
    } else if index < 0 || index >= codec.total_count() {
      reason_code = Some("ERASURE_INDEX")
    } else if present[index] {
      reason_code = Some("ERASURE_DUPLICATE_INDEX")
    } else {
      present[index] = true
      present_count = present_count + 1
    }
  }
  let missing_indices : Array[Int] = []
  for index = 0; index < present.length(); index = index + 1 {
    if !present[index] {
      missing_indices.push(index)
    }
  }
  match reason_code {
    Some(code) =>
      return invalid_health(stripe_index, present_count, missing_indices, code)
    None => ()
  }
  if present_count < codec.data_count() {
    return {
      stripe_index,
      status: Unrecoverable,
      present_count,
      missing_indices,
      reason_code: Some("ERASURE_NOT_ENOUGH_SHARDS"),
    }
  }
  let checked = try recover_stripe(codec, frames, set_id, stripe_index) catch {
    error => Some(error.code())
  } noraise {
    _ => None
  }
  match checked {
    Some(code) =>
      invalid_health(stripe_index, present_count, missing_indices, code)
    None =>
      {
        stripe_index,
        status: if missing_indices.length() == 0 {
          Healthy
        } else {
          Repairable
        },
        present_count,
        missing_indices,
        reason_code: None,
      }
  }
}

///|
pub struct ObjectHealth {
  stripes : Array[StripeHealth]
  healthy_count : Int
  repairable_count : Int
  unrecoverable_count : Int
  invalid_count : Int
}

///|
pub fn ObjectHealth::stripes(self : ObjectHealth) -> Array[StripeHealth] {
  let copy : Array[StripeHealth] = []
  for stripe in self.stripes {
    copy.push(stripe)
  }
  copy
}

///|
pub fn ObjectHealth::healthy_count(self : ObjectHealth) -> Int {
  self.healthy_count
}

///|
pub fn ObjectHealth::repairable_count(self : ObjectHealth) -> Int {
  self.repairable_count
}

///|
pub fn ObjectHealth::unrecoverable_count(self : ObjectHealth) -> Int {
  self.unrecoverable_count
}

///|
pub fn ObjectHealth::invalid_count(self : ObjectHealth) -> Int {
  self.invalid_count
}

///|
pub fn ObjectHealth::fully_recoverable(self : ObjectHealth) -> Bool {
  self.unrecoverable_count == 0 && self.invalid_count == 0
}

///|
/// Inspect every stripe against a manifest. The caller may decide which
/// repairable stripes to reconstruct and where to place replacement shards.
pub fn inspect_object(
  manifest : Manifest,
  frames : Array[ShardEnvelope],
  max_encoded_bytes? : Int = 16_777_216,
) -> ObjectHealth raise ErasureError {
  let codec = Codec::new(
    manifest.data_count(),
    manifest.parity_count(),
    max_encoded_bytes~,
  )
  if manifest.stripe_payload_limit() >
    codec.data_count() * codec.max_shard_bytes() {
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
    let index = frame.stripe_index()
    if index < 0 || index >= manifest.stripe_count() {
      raise InvalidIndex(index)
    }
    groups[index].push(frame)
  }
  let stripes : Array[StripeHealth] = []
  let mut healthy_count = 0
  let mut repairable_count = 0
  let mut unrecoverable_count = 0
  let mut invalid_count = 0
  for index = 0; index < groups.length(); index = index + 1 {
    let report = inspect_stripe(codec, groups[index], manifest.set_id(), index)
    match report.status() {
      Healthy => healthy_count = healthy_count + 1
      Repairable => repairable_count = repairable_count + 1
      Unrecoverable => unrecoverable_count = unrecoverable_count + 1
      InvalidInput => invalid_count = invalid_count + 1
    }
    stripes.push(report)
  }
  {
    stripes,
    healthy_count,
    repairable_count,
    unrecoverable_count,
    invalid_count,
  }
}
