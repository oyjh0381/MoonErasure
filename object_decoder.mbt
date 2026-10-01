///|
/// Sequential decoder for objects whose frames are fetched stripe by stripe.
/// The caller groups each stripe's available frames and can write each
/// returned payload chunk directly to a destination.
pub struct ObjectDecoder {
  codec : Codec
  manifest : Manifest
  mut next_stripe : Int
  mut decoded_bytes : Int
  mut repaired_shards : Int
}

///|
pub fn ObjectDecoder::new(
  manifest : Manifest,
  max_encoded_bytes? : Int = 16_777_216,
) -> ObjectDecoder raise ErasureError {
  let codec = Codec::new(
    manifest.data_count(),
    manifest.parity_count(),
    max_encoded_bytes~,
  )
  if manifest.stripe_payload_limit() > codec.data_count() * codec.max_shard_bytes() {
    raise ResourceLimit("codec budget cannot hold manifest stripe")
  }
  {
    codec,
    manifest,
    next_stripe: 0,
    decoded_bytes: 0,
    repaired_shards: 0,
  }
}

///|
pub fn ObjectDecoder::next_stripe(self : ObjectDecoder) -> Int {
  self.next_stripe
}

///|
pub fn ObjectDecoder::decoded_bytes(self : ObjectDecoder) -> Int {
  self.decoded_bytes
}

///|
pub fn ObjectDecoder::repaired_shards(self : ObjectDecoder) -> Int {
  self.repaired_shards
}

///|
/// Decode exactly the next manifest stripe. On failure, the cursor remains
/// unchanged so callers may fetch an alternative frame and retry.
pub fn ObjectDecoder::push_stripe(
  self : ObjectDecoder,
  frames : Array[ShardEnvelope],
) -> Bytes raise ErasureError {
  if self.next_stripe >= self.manifest.stripe_count() {
    raise InvalidManifest("decoder received extra stripe")
  }
  let recovery = recover_stripe(
    self.codec,
    frames,
    self.manifest.set_id(),
    self.next_stripe,
  )
  let payload = recovery.payload()
  if payload.length() != self.manifest.stripe_length(self.next_stripe) {
    raise InvalidManifest("decoded stripe length differs from manifest")
  }
  self.decoded_bytes = self.decoded_bytes + payload.length()
  self.repaired_shards = self.repaired_shards + recovery.missing_indices().length()
  self.next_stripe = self.next_stripe + 1
  payload
}

///|
/// Confirm that every stripe was consumed and the advertised byte count
/// matches. There is no hidden payload buffer in this decoder.
pub fn ObjectDecoder::finish(self : ObjectDecoder) -> Int raise ErasureError {
  if self.next_stripe != self.manifest.stripe_count() ||
    self.decoded_bytes != self.manifest.total_length() {
    raise InvalidManifest("decoder ended before final stripe")
  }
  self.repaired_shards
}
