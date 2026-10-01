///|
/// Recover only the stripes overlapping a byte range. Callers may supply
/// frames for the whole object or only for the requested stripes. Damage in
/// unrelated stripes does not block a range read.
pub fn recover_object_range(
  manifest : Manifest,
  frames : Array[ShardEnvelope],
  start : Int,
  length : Int,
  max_encoded_bytes? : Int = 16_777_216,
) -> Bytes raise ErasureError {
  if start < 0 || length < 0 || start > manifest.total_length() ||
    length > manifest.total_length() - start {
    raise InvalidRange
  }
  if length == 0 {
    return b""
  }
  let codec = Codec::new(
    manifest.data_count(),
    manifest.parity_count(),
    max_encoded_bytes~,
  )
  if manifest.stripe_payload_limit() > codec.data_count() * codec.max_shard_bytes() {
    raise ResourceLimit("codec budget cannot hold manifest stripe")
  }
  let first = start / manifest.stripe_payload_limit()
  let last = (start + length - 1) / manifest.stripe_payload_limit()
  let groups : Array[Array[ShardEnvelope]] = []
  for index = first; index <= last; index = index + 1 {
    groups.push([])
  }
  for frame in frames {
    if frame.set_id() != manifest.set_id() {
      raise InvalidManifest("range frame set id differs from manifest")
    }
    let stripe_index = frame.stripe_index()
    if stripe_index < 0 || stripe_index >= manifest.stripe_count() {
      raise InvalidIndex(stripe_index)
    }
    if stripe_index >= first && stripe_index <= last {
      groups[stripe_index - first].push(frame)
    }
  }
  let output = Array::make(length, b'\x00')
  for stripe_index = first; stripe_index <= last; stripe_index = stripe_index + 1 {
    let recovered = recover_stripe(
      codec,
      groups[stripe_index - first],
      manifest.set_id(),
      stripe_index,
    )
    let stripe_payload = recovered.payload()
    let stripe_start = stripe_index * manifest.stripe_payload_limit()
    if stripe_payload.length() != manifest.stripe_length(stripe_index) {
      raise InvalidManifest("range stripe length differs from manifest")
    }
    let mut copy_start = start
    if stripe_start > copy_start {
      copy_start = stripe_start
    }
    let mut copy_end = start + length
    if stripe_start + stripe_payload.length() < copy_end {
      copy_end = stripe_start + stripe_payload.length()
    }
    for position = copy_start; position < copy_end; position = position + 1 {
      output[position - start] = stripe_payload[position - stripe_start]
    }
  }
  Bytes::from_array(output)
}
