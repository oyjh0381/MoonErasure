///|
/// A complete repaired stripe plus information about which shards were absent.
pub struct StripeRecovery {
  payload : Bytes
  shards : Array[ShardEnvelope]
  missing_indices : Array[Int]
  provided_count : Int
}

///|
pub fn StripeRecovery::payload(self : StripeRecovery) -> Bytes {
  copy_shard(self.payload)
}

///|
pub fn StripeRecovery::shards(self : StripeRecovery) -> Array[ShardEnvelope] {
  let result : Array[ShardEnvelope] = []
  for shard in self.shards {
    result.push(shard)
  }
  result
}

///|
pub fn StripeRecovery::missing_indices(self : StripeRecovery) -> Array[Int] {
  let result : Array[Int] = []
  for index in self.missing_indices {
    result.push(index)
  }
  result
}

///|
pub fn StripeRecovery::provided_count(self : StripeRecovery) -> Int {
  self.provided_count
}

///|
/// Split one nonempty payload into equal padded data shards and encode parity.
pub fn encode_stripe(
  codec : Codec,
  payload : Bytes,
  set_id : Int,
  stripe_index : Int,
) -> Array[ShardEnvelope] raise ErasureError {
  if payload.length() < 1 {
    raise EmptyShard
  }
  if payload.length() > codec.data_count() * codec.max_shard_bytes() {
    raise ResourceLimit("payload exceeds one stripe's data capacity")
  }
  let mut length = payload.length() / codec.data_count()
  if payload.length() % codec.data_count() != 0 {
    length = length + 1
  }
  let data : Array[Bytes] = []
  for shard_index = 0; shard_index < codec.data_count(); shard_index = shard_index + 1 {
    let bytes = Array::make(length, b'\x00')
    for offset = 0; offset < length; offset = offset + 1 {
      let position = shard_index * length + offset
      if position < payload.length() {
        bytes[offset] = payload[position]
      }
    }
    data.push(Bytes::from_array(bytes))
  }
  let all = codec.encode_all(data)
  let frames : Array[ShardEnvelope] = []
  for shard_index = 0; shard_index < all.length(); shard_index = shard_index + 1 {
    frames.push(
      ShardEnvelope::new(
        codec,
        set_id,
        stripe_index,
        shard_index,
        payload.length(),
        all[shard_index],
      ),
    )
  }
  frames
}

///|
/// Recover a stripe from validated envelopes. Duplicate indices, mixed
/// identities, mismatched sizes and inconsistent extra shards are rejected.
pub fn recover_stripe(
  codec : Codec,
  frames : Array[ShardEnvelope],
  set_id : Int,
  stripe_index : Int,
) -> StripeRecovery raise ErasureError {
  if set_id < 0 || stripe_index < 0 {
    raise InvalidEnvelope("set and stripe ids must be nonnegative")
  }
  let present : Array[Bytes?] = Array::make(codec.total_count(), None)
  let mut original_length = -1
  let mut shard_length = -1
  for frame in frames {
    if frame.set_id() != set_id || frame.stripe_index() != stripe_index {
      raise InvalidEnvelope("frame belongs to another set or stripe")
    }
    if frame.data_count() != codec.data_count() ||
      frame.parity_count() != codec.parity_count() {
      raise InvalidEnvelope("frame codec dimensions do not match")
    }
    let index = frame.shard_index()
    if index < 0 || index >= codec.total_count() {
      raise InvalidIndex(index)
    }
    if present[index] is Some(_) {
      raise DuplicateIndex(index)
    }
    if original_length == -1 {
      original_length = frame.original_length()
      shard_length = frame.payload.length()
    } else if frame.original_length() != original_length ||
      frame.payload.length() != shard_length {
      raise InvalidEnvelope("frame lengths disagree within stripe")
    }
    present[index] = Some(frame.payload())
  }
  if frames.length() < codec.data_count() {
    raise NotEnoughShards(required=codec.data_count(), available=frames.length())
  }
  if original_length < 1 || original_length > codec.data_count() * shard_length {
    raise InvalidEnvelope("invalid stripe original length")
  }
  let missing_indices : Array[Int] = []
  for index = 0; index < present.length(); index = index + 1 {
    if present[index] is None {
      missing_indices.push(index)
    }
  }
  let rebuilt = codec.reconstruct(present)
  for position = original_length; position < codec.data_count() * shard_length; position = position + 1 {
    if rebuilt[position / shard_length][position % shard_length] != b'\x00' {
      raise InvalidEnvelope("nonzero bytes in padded data tail")
    }
  }
  let payload = Array::make(original_length, b'\x00')
  for position = 0; position < original_length; position = position + 1 {
    payload[position] = rebuilt[position / shard_length][position % shard_length]
  }
  let envelopes : Array[ShardEnvelope] = []
  for index = 0; index < rebuilt.length(); index = index + 1 {
    envelopes.push(
      ShardEnvelope::new(
        codec,
        set_id,
        stripe_index,
        index,
        original_length,
        rebuilt[index],
      ),
    )
  }
  {
    payload: Bytes::from_array(payload),
    shards: envelopes,
    missing_indices,
    provided_count: frames.length(),
  }
}
