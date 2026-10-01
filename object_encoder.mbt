///|
/// Incremental object encoder with an upfront manifest. Applications can
/// persist completed frames immediately, keeping only one stripe in memory.
pub struct ObjectEncoder {
  codec : Codec
  manifest : Manifest
  mut pending : Array[Byte]
  mut accepted_bytes : Int
  mut emitted_stripes : Int
}

///|
pub fn ObjectEncoder::new(
  codec : Codec,
  set_id : Int,
  total_length : Int,
  stripe_payload_limit? : Int = 65_536,
  max_object_bytes? : Int = 67_108_864,
) -> ObjectEncoder raise ErasureError {
  let manifest = Manifest::new(
    codec,
    set_id,
    stripe_payload_limit,
    total_length,
    max_object_bytes~,
  )
  { codec, manifest, pending: [], accepted_bytes: 0, emitted_stripes: 0, }
}

///|
pub fn ObjectEncoder::manifest(self : ObjectEncoder) -> Manifest {
  self.manifest
}

///|
pub fn ObjectEncoder::accepted_bytes(self : ObjectEncoder) -> Int {
  self.accepted_bytes
}

///|
pub fn ObjectEncoder::emitted_stripes(self : ObjectEncoder) -> Int {
  self.emitted_stripes
}

///|
pub fn ObjectEncoder::buffered_bytes(self : ObjectEncoder) -> Int {
  self.pending.length()
}

///|
/// Accept a chunk of the declared object. A chunk may complete zero, one,
/// or many stripes. Exceeding the advertised size is rejected before mutation.
pub fn ObjectEncoder::push(
  self : ObjectEncoder,
  chunk : Bytes,
) -> Array[ShardEnvelope] raise ErasureError {
  if chunk.length() > self.manifest.total_length() - self.accepted_bytes {
    raise ResourceLimit("encoder input exceeds declared object length")
  }
  let frames : Array[ShardEnvelope] = []
  for byte in chunk {
    self.pending.push(byte)
    self.accepted_bytes = self.accepted_bytes + 1
    let target = self.manifest.stripe_length(self.emitted_stripes)
    if self.pending.length() == target {
      let complete = encode_stripe(
        self.codec,
        Bytes::from_array(self.pending),
        self.manifest.set_id(),
        self.emitted_stripes,
      )
      for frame in complete {
        frames.push(frame)
      }
      self.pending = []
      self.emitted_stripes = self.emitted_stripes + 1
    }
  }
  frames
}

///|
/// Confirm the stream ended exactly at the declared length and every stripe
/// was emitted. Empty objects finish without emitting frames.
pub fn ObjectEncoder::finish(
  self : ObjectEncoder,
) -> Manifest raise ErasureError {
  if self.accepted_bytes != self.manifest.total_length() ||
    self.emitted_stripes != self.manifest.stripe_count() ||
    self.pending.length() != 0 {
    raise InvalidManifest("encoder input ended before declared object length")
  }
  self.manifest
}
