///|
/// Single-file archive: 24-byte bundle header, 32-byte manifest, then a
/// length-prefixed sequence of complete shard frames. Individual frames retain
/// their own checksums so they can also be extracted and stored independently.
pub fn export_bundle(
  object : EncodedObject,
  max_output_bytes? : Int = 134_217_728,
) -> Bytes raise ErasureError {
  if max_output_bytes < 56 || max_output_bytes > 268_435_456 {
    raise InvalidConfiguration("bundle byte budget must fit headers and be <= 256 MiB")
  }
  let manifest = object.manifest()
  let expected = manifest.stripe_count() *
    (manifest.data_count() + manifest.parity_count())
  if object.frame_count() != expected {
    raise InvalidManifest("object frame count disagrees with manifest")
  }
  let frames = object.frames()
  let output : Array[Byte] = [b'M', b'E', b'R', b'B', b'\x01', b'\x00']
  write_u16(output, 24)
  write_u32(output, 32U)
  write_u32(output, frames.length().reinterpret_as_uint())
  write_u32(output, 0U)
  write_u32(output, crc32c(Bytes::from_array(output)))
  for byte in manifest.to_bytes() {
    output.push(byte)
  }
  for frame in frames {
    let bytes = frame.to_bytes()
    if bytes.length() + 4 > max_output_bytes - output.length() {
      raise ResourceLimit("bundle output exceeds byte budget")
    }
    write_u32(output, bytes.length().reinterpret_as_uint())
    for byte in bytes {
      output.push(byte)
    }
  }
  Bytes::from_array(output)
}

///|
/// Strictly import one complete bundle and validate every stripe. This
/// archive path refuses damage; individual frame recovery remains available
/// through `recover_serialized_stripe` when some bytes are unavailable.
pub fn import_bundle(
  input : Bytes,
  max_input_bytes? : Int = 134_217_728,
  max_object_bytes? : Int = 67_108_864,
  max_encoded_bytes? : Int = 16_777_216,
) -> EncodedObject raise ErasureError {
  if max_input_bytes < 56 || max_input_bytes > 268_435_456 {
    raise InvalidConfiguration("bundle input byte budget must be <= 256 MiB")
  }
  if input.length() > max_input_bytes {
    raise ResourceLimit("bundle input exceeds byte budget")
  }
  if input.length() < 56 {
    raise InvalidEnvelope("bundle is shorter than both headers")
  }
  if input[0] != b'M' || input[1] != b'E' || input[2] != b'R' ||
    input[3] != b'B' {
    raise InvalidEnvelope("bad bundle magic")
  }
  let version = input[4].to_int()
  if version != 1 {
    raise UnsupportedVersion(version)
  }
  if input[5] != b'\x00' || read_u16(input, 6) != 24 ||
    read_u32(input, 8) != 32U || read_u32(input, 16) != 0U {
    raise InvalidEnvelope("bundle header fields are invalid")
  }
  let expected_checksum = crc32c(Bytes::from_array(input[0:20].to_array()))
  if read_u32(input, 20) != expected_checksum {
    raise ChecksumMismatch(-1)
  }
  let frame_count = read_bounded_int(input, 12)
  let manifest = Manifest::from_bytes(
    Bytes::from_array(input[24:56].to_array()),
    max_object_bytes~,
    max_encoded_bytes~,
  )
  let expected_frames = manifest.stripe_count() *
    (manifest.data_count() + manifest.parity_count())
  if frame_count != expected_frames {
    raise InvalidManifest("bundle frame count disagrees with manifest")
  }
  let frames : Array[ShardEnvelope] = []
  let mut offset = 56
  for _ in 0..<frame_count {
    if input.length() - offset < 4 {
      raise InvalidEnvelope("truncated frame length")
    }
    let length = read_bounded_int(input, offset)
    offset = offset + 4
    if length < 33 || length > input.length() - offset {
      raise InvalidEnvelope("invalid or truncated frame payload")
    }
    frames.push(
      ShardEnvelope::from_bytes(
        Bytes::from_array(input[offset:offset + length].to_array()),
        max_encoded_bytes~,
      ),
    )
    offset = offset + length
  }
  if offset != input.length() {
    raise InvalidEnvelope("trailing bytes after final frame")
  }
  ignore(recover_object(manifest, frames, max_encoded_bytes~))
  { manifest, frames }
}
