///|
/// Castagnoli CRC-32C for accidental-damage detection. This is not a MAC.
fn crc32c_update(state : UInt, byte : Byte) -> UInt {
  let mut current = state ^ byte.to_uint()
  for _ in 0..<8 {
    if (current & 1U) == 1U {
      current = (current >> 1) ^ 0x82f63b78U
    } else {
      current = current >> 1
    }
  }
  current
}

///|
pub fn crc32c(input : Bytes) -> UInt {
  let mut state = 0xffffffffU
  for byte in input {
    state = crc32c_update(state, byte)
  }
  state ^ 0xffffffffU
}

///|
fn crc32c_header_payload(header : Array[Byte], payload : Bytes) -> UInt {
  let mut state = 0xffffffffU
  for index = 0; index < 28; index = index + 1 {
    state = crc32c_update(state, header[index])
  }
  for byte in payload {
    state = crc32c_update(state, byte)
  }
  state ^ 0xffffffffU
}
