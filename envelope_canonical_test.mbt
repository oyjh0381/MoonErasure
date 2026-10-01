///|
test "envelope constructor requires canonical ceil division shard length" {
  let codec = try! @moonerasure.Codec::new(3, 2)
  let code = try
    @moonerasure.ShardEnvelope::new(codec, 1, 0, 0, 4, b"abc")
  catch {
    error => error.code()
  } noraise {
    _ => "unexpected success"
  }
  assert_eq(code, "ERASURE_ENVELOPE")
  ignore(try! @moonerasure.ShardEnvelope::new(codec, 1, 0, 0, 4, b"ab"))
}

///|
test "parser rejects noncanonical padded frame even with valid CRC" {
  let codec = try! @moonerasure.Codec::new(2, 1)
  let frame = try! @moonerasure.ShardEnvelope::new(codec, 1, 0, 0, 3, b"ab")
  let bytes = frame.to_bytes().to_array()
  bytes.push(b'\x00')
  let header : Array[Byte] = []
  for index = 0; index < 28; index = index + 1 {
    header.push(bytes[index])
  }
  for index = 32; index < bytes.length(); index = index + 1 {
    header.push(bytes[index])
  }
  let checksum = @moonerasure.crc32c(Bytes::from_array(header))
  for shift = 0; shift < 4; shift = shift + 1 {
    bytes[28 + shift] = ((checksum >> (shift * 8)) & 0xffU).to_byte()
  }
  let code = try
    @moonerasure.ShardEnvelope::from_bytes(Bytes::from_array(bytes))
  catch {
    error => error.code()
  } noraise {
    _ => "unexpected success"
  }
  assert_eq(code, "ERASURE_ENVELOPE")
}
