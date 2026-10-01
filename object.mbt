///|
/// A bounded in-memory object ready for caller-controlled placement.
pub struct EncodedObject {
  manifest : Manifest
  frames : Array[ShardEnvelope]
}

///|
pub fn EncodedObject::manifest(self : EncodedObject) -> Manifest {
  self.manifest
}

///|
pub fn EncodedObject::frames(self : EncodedObject) -> Array[ShardEnvelope] {
  let copy : Array[ShardEnvelope] = []
  for frame in self.frames {
    copy.push(frame)
  }
  copy
}

///|
pub fn EncodedObject::frame_count(self : EncodedObject) -> Int {
  self.frames.length()
}

///|
pub struct ObjectRecovery {
  payload : Bytes
  repaired_shard_count : Int
  stripe_count : Int
}

///|
pub fn ObjectRecovery::payload(self : ObjectRecovery) -> Bytes {
  copy_shard(self.payload)
}

///|
pub fn ObjectRecovery::repaired_shard_count(self : ObjectRecovery) -> Int {
  self.repaired_shard_count
}

///|
pub fn ObjectRecovery::stripe_count(self : ObjectRecovery) -> Int {
  self.stripe_count
}

///|
/// Split an object into bounded, independently recoverable stripes.
pub fn encode_object(
  codec : Codec,
  payload : Bytes,
  set_id : Int,
  stripe_payload_limit? : Int = 65_536,
  max_object_bytes? : Int = 67_108_864,
  max_output_bytes? : Int = 134_217_728,
) -> EncodedObject raise ErasureError {
  if max_output_bytes < 0 || max_output_bytes > 268_435_456 {
    raise InvalidConfiguration("output byte budget must be <= 256 MiB")
  }
  let manifest = Manifest::new(
    codec,
    set_id,
    stripe_payload_limit,
    payload.length(),
    max_object_bytes~,
  )
  let frames : Array[ShardEnvelope] = []
  let mut offset = 0
  let mut output_bytes = 0
  for stripe_index = 0; stripe_index < manifest.stripe_count(); stripe_index = stripe_index + 1 {
    let stripe_length = manifest.stripe_length(stripe_index)
    let mut shard_length = stripe_length / codec.data_count()
    if stripe_length % codec.data_count() != 0 {
      shard_length = shard_length + 1
    }
    let frame_length = 32 + shard_length
    if frame_length > (max_output_bytes - output_bytes) / codec.total_count() {
      raise ResourceLimit("encoded object exceeds output byte budget")
    }
    output_bytes = output_bytes + frame_length * codec.total_count()
    let chunk = Bytes::from_array(payload[offset:offset + stripe_length].to_array())
    let stripe = encode_stripe(codec, chunk, set_id, stripe_index)
    for frame in stripe {
      frames.push(frame)
    }
    offset = offset + stripe_length
  }
  { manifest, frames }
}

///|
/// Reassemble in manifest order; every stripe must have enough intact frames.
/// For individual repaired shard bytes, call `recover_stripe` on that stripe.
pub fn recover_object(
  manifest : Manifest,
  frames : Array[ShardEnvelope],
  max_encoded_bytes? : Int = 16_777_216,
) -> ObjectRecovery raise ErasureError {
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
      raise InvalidManifest("frame set id differs from manifest")
    }
    let stripe_index = frame.stripe_index()
    if stripe_index < 0 || stripe_index >= manifest.stripe_count() {
      raise InvalidIndex(stripe_index)
    }
    groups[stripe_index].push(frame)
  }
  let output = Array::make(manifest.total_length(), b'\x00')
  let mut offset = 0
  let mut repaired_shard_count = 0
  for index = 0; index < manifest.stripe_count(); index = index + 1 {
    let result = recover_stripe(codec, groups[index], manifest.set_id(), index)
    let stripe_payload = result.payload()
    if stripe_payload.length() != manifest.stripe_length(index) {
      raise InvalidManifest("stripe length differs from manifest")
    }
    for byte in stripe_payload {
      output[offset] = byte
      offset = offset + 1
    }
    repaired_shard_count = repaired_shard_count + result.missing_indices().length()
  }
  {
    payload: Bytes::from_array(output),
    repaired_shard_count,
    stripe_count: manifest.stripe_count(),
  }
}
