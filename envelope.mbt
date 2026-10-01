///|
/// Version 1 frame: 28-byte metadata, 4-byte CRC32C, then shard payload.
/// Integer fields are unsigned little-endian; ids and lengths are capped at
/// signed 31-bit values so they behave identically on all MoonBit targets.
pub struct ShardEnvelope {
  set_id : Int
  stripe_index : Int
  shard_index : Int
  data_count : Int
  parity_count : Int
  original_length : Int
  payload : Bytes
}

///|
pub fn ShardEnvelope::new(
  codec : Codec,
  set_id : Int,
  stripe_index : Int,
  shard_index : Int,
  original_length : Int,
  payload : Bytes,
) -> ShardEnvelope raise ErasureError {
  if set_id < 0 || stripe_index < 0 {
    raise InvalidEnvelope("set and stripe ids must be nonnegative")
  }
  if shard_index < 0 || shard_index >= codec.total_count() {
    raise InvalidIndex(shard_index)
  }
  codec.check_length(payload.length())
  if original_length < 1 || original_length > codec.data_count() * payload.length() {
    raise InvalidEnvelope("original length must fit in data shards")
  }
  let expected_length = (original_length - 1) / codec.data_count() + 1
  if payload.length() != expected_length {
    raise InvalidEnvelope("shard payload length is not canonical")
  }
  {
    set_id,
    stripe_index,
    shard_index,
    data_count: codec.data_count(),
    parity_count: codec.parity_count(),
    original_length,
    payload: copy_shard(payload),
  }
}

///|
pub fn ShardEnvelope::set_id(self : ShardEnvelope) -> Int {
  self.set_id
}

///|
pub fn ShardEnvelope::stripe_index(self : ShardEnvelope) -> Int {
  self.stripe_index
}

///|
pub fn ShardEnvelope::shard_index(self : ShardEnvelope) -> Int {
  self.shard_index
}

///|
pub fn ShardEnvelope::data_count(self : ShardEnvelope) -> Int {
  self.data_count
}

///|
pub fn ShardEnvelope::parity_count(self : ShardEnvelope) -> Int {
  self.parity_count
}

///|
pub fn ShardEnvelope::original_length(self : ShardEnvelope) -> Int {
  self.original_length
}

///|
pub fn ShardEnvelope::payload(self : ShardEnvelope) -> Bytes {
  copy_shard(self.payload)
}

///|
fn write_u16(output : Array[Byte], value : Int) -> Unit {
  output.push((value & 0xff).to_byte())
  output.push(((value >> 8) & 0xff).to_byte())
}

///|
fn write_u32(output : Array[Byte], value : UInt) -> Unit {
  for shift in [0, 8, 16, 24] {
    output.push(((value >> shift) & 0xffU).to_byte())
  }
}

///|
fn read_u16(input : Bytes, offset : Int) -> Int {
  input[offset].to_int() | (input[offset + 1].to_int() << 8)
}

///|
fn read_u32(input : Bytes, offset : Int) -> UInt {
  input[offset].to_uint() |
  (input[offset + 1].to_uint() << 8) |
  (input[offset + 2].to_uint() << 16) |
  (input[offset + 3].to_uint() << 24)
}

///|
fn read_bounded_int(input : Bytes, offset : Int) -> Int raise ErasureError {
  let value = read_u32(input, offset)
  if value > 0x7fffffffU {
    raise InvalidEnvelope("integer exceeds portable signed range")
  }
  value.reinterpret_as_int()
}

///|
/// Serialize a validated envelope with a CRC covering metadata and payload.
pub fn ShardEnvelope::to_bytes(self : ShardEnvelope) -> Bytes {
  let output : Array[Byte] = [b'M', b'E', b'R', b'S', b'\x01', b'\x00']
  write_u16(output, 32)
  write_u32(output, self.set_id.reinterpret_as_uint())
  write_u32(output, self.stripe_index.reinterpret_as_uint())
  write_u16(output, self.shard_index)
  write_u16(output, self.data_count)
  write_u16(output, self.parity_count)
  write_u16(output, 0)
  write_u32(output, self.original_length.reinterpret_as_uint())
  let checksum = crc32c_header_payload(output, self.payload)
  write_u32(output, checksum)
  for byte in self.payload {
    output.push(byte)
  }
  Bytes::from_array(output)
}

///|
/// Parse one bounded frame. Invalid metadata and damaged payloads fail closed.
pub fn ShardEnvelope::from_bytes(
  input : Bytes,
  max_encoded_bytes? : Int = 16_777_216,
) -> ShardEnvelope raise ErasureError {
  if input.length() < 33 {
    raise InvalidEnvelope("frame is shorter than header plus one payload byte")
  }
  if input[0] != b'M' || input[1] != b'E' || input[2] != b'R' ||
    input[3] != b'S' {
    raise InvalidEnvelope("bad magic")
  }
  let version = input[4].to_int()
  if version != 1 {
    raise UnsupportedVersion(version)
  }
  if input[5] != b'\x00' || read_u16(input, 6) != 32 ||
    read_u16(input, 22) != 0 {
    raise InvalidEnvelope("nonzero flags, reserved bytes or wrong header length")
  }
  let set_id = read_bounded_int(input, 8)
  let stripe_index = read_bounded_int(input, 12)
  let shard_index = read_u16(input, 16)
  let data_count = read_u16(input, 18)
  let parity_count = read_u16(input, 20)
  let original_length = read_bounded_int(input, 24)
  let max_shard_bytes = validated_max_shard_bytes(
    data_count,
    parity_count,
    max_encoded_bytes,
  )
  if shard_index >= data_count + parity_count {
    raise InvalidIndex(shard_index)
  }
  let length = input.length() - 32
  if length > max_shard_bytes {
    raise ResourceLimit("frame payload exceeds encoded byte budget")
  }
  if original_length < 1 || original_length > data_count * length {
    raise InvalidEnvelope("original length does not fit data shards")
  }
  if length != (original_length - 1) / data_count + 1 {
    raise InvalidEnvelope("shard payload length is not canonical")
  }
  let payload = Bytes::from_array(input[32:input.length()].to_array())
  let header = input[0:28].to_array()
  let expected = read_u32(input, 28)
  if crc32c_header_payload(header, payload) != expected {
    raise ChecksumMismatch(shard_index)
  }
  {
    set_id,
    stripe_index,
    shard_index,
    data_count,
    parity_count,
    original_length,
    payload,
  }
}
