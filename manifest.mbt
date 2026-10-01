///|
/// Bounded description of an ordered sequence of independently coded stripes.
pub struct Manifest {
  set_id : Int
  data_count : Int
  parity_count : Int
  stripe_payload_limit : Int
  stripe_count : Int
  total_length : Int
}

///|
pub fn Manifest::new(
  codec : Codec,
  set_id : Int,
  stripe_payload_limit : Int,
  total_length : Int,
  max_object_bytes? : Int = 67_108_864,
) -> Manifest raise ErasureError {
  if set_id < 0 {
    raise InvalidManifest("set id must be nonnegative")
  }
  if max_object_bytes < 0 || max_object_bytes > 268_435_456 {
    raise InvalidConfiguration("object byte budget must be <= 256 MiB")
  }
  if total_length < 0 || total_length > max_object_bytes {
    raise ResourceLimit("object exceeds byte budget")
  }
  if stripe_payload_limit < 1 ||
    stripe_payload_limit > codec.data_count() * codec.max_shard_bytes() {
    raise InvalidManifest("stripe payload limit exceeds codec capacity")
  }
  let mut stripe_count = total_length / stripe_payload_limit
  if total_length % stripe_payload_limit != 0 {
    stripe_count = stripe_count + 1
  }
  if stripe_count > 4096 {
    raise ResourceLimit("object exceeds 4096 stripes")
  }
  {
    set_id,
    data_count: codec.data_count(),
    parity_count: codec.parity_count(),
    stripe_payload_limit,
    stripe_count,
    total_length,
  }
}

///|
pub fn Manifest::set_id(self : Manifest) -> Int {
  self.set_id
}

///|
pub fn Manifest::data_count(self : Manifest) -> Int {
  self.data_count
}

///|
pub fn Manifest::parity_count(self : Manifest) -> Int {
  self.parity_count
}

///|
pub fn Manifest::stripe_count(self : Manifest) -> Int {
  self.stripe_count
}

///|
pub fn Manifest::total_length(self : Manifest) -> Int {
  self.total_length
}

///|
pub fn Manifest::stripe_payload_limit(self : Manifest) -> Int {
  self.stripe_payload_limit
}

///|
pub fn Manifest::stripe_length(self : Manifest, index : Int) -> Int raise ErasureError {
  if index < 0 || index >= self.stripe_count {
    raise InvalidIndex(index)
  }
  let remaining = self.total_length - index * self.stripe_payload_limit
  if remaining > self.stripe_payload_limit {
    self.stripe_payload_limit
  } else {
    remaining
  }
}

///|
/// 28 bytes of metadata followed by CRC32C of those 28 bytes.
pub fn Manifest::to_bytes(self : Manifest) -> Bytes {
  let output : Array[Byte] = [b'M', b'E', b'R', b'M', b'\x01', b'\x00']
  write_u16(output, 32)
  write_u32(output, self.set_id.reinterpret_as_uint())
  write_u16(output, self.data_count)
  write_u16(output, self.parity_count)
  write_u32(output, self.stripe_payload_limit.reinterpret_as_uint())
  write_u32(output, self.stripe_count.reinterpret_as_uint())
  write_u32(output, self.total_length.reinterpret_as_uint())
  write_u32(output, crc32c(Bytes::from_array(output)))
  Bytes::from_array(output)
}

///|
pub fn Manifest::from_bytes(
  input : Bytes,
  max_object_bytes? : Int = 67_108_864,
  max_encoded_bytes? : Int = 16_777_216,
) -> Manifest raise ErasureError {
  if input.length() != 32 {
    raise InvalidManifest("manifest must be exactly 32 bytes")
  }
  if input[0] != b'M' || input[1] != b'E' || input[2] != b'R' ||
    input[3] != b'M' {
    raise InvalidManifest("bad manifest magic")
  }
  let version = input[4].to_int()
  if version != 1 {
    raise UnsupportedVersion(version)
  }
  if input[5] != b'\x00' || read_u16(input, 6) != 32 {
    raise InvalidManifest("invalid manifest flags or length")
  }
  let actual = crc32c(Bytes::from_array(input[0:28].to_array()))
  if read_u32(input, 28) != actual {
    raise ChecksumMismatch(-1)
  }
  let set_id = read_bounded_int(input, 8)
  let data_count = read_u16(input, 12)
  let parity_count = read_u16(input, 14)
  let stripe_payload_limit = read_bounded_int(input, 16)
  let stored_stripe_count = read_bounded_int(input, 20)
  let total_length = read_bounded_int(input, 24)
  let codec = Codec::new(data_count, parity_count, max_encoded_bytes~)
  let manifest = Manifest::new(
    codec,
    set_id,
    stripe_payload_limit,
    total_length,
    max_object_bytes~,
  )
  if manifest.stripe_count != stored_stripe_count {
    raise InvalidManifest("stored stripe count disagrees with lengths")
  }
  manifest
}
