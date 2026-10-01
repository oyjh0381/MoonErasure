///|
test "manifest parser validates large dimensions without matrix construction" {
  let header : Array[Byte] = [b'M', b'E', b'R', b'M', b'\x01', b'\x00']
  write_u16(header, 32)
  write_u32(header, 1U)
  write_u16(header, 255)
  write_u16(header, 1)
  write_u32(header, 1U)
  write_u32(header, 1U)
  write_u32(header, 1U)
  write_u32(header, crc32c(Bytes::from_array(header)))
  let manifest = try! Manifest::from_bytes(Bytes::from_array(header))
  assert_eq(manifest.data_count(), 255)
  assert_eq(manifest.stripe_count(), 1)
}

///|
test "manifest parser rejects oversized shard dimensions before allocation" {
  let header : Array[Byte] = [b'M', b'E', b'R', b'M', b'\x01', b'\x00']
  write_u16(header, 32)
  write_u32(header, 1U)
  write_u16(header, 65535)
  write_u16(header, 65535)
  write_u32(header, 1U)
  write_u32(header, 1U)
  write_u32(header, 1U)
  write_u32(header, crc32c(Bytes::from_array(header)))
  let rejected = try Manifest::from_bytes(Bytes::from_array(header)) catch {
    InvalidConfiguration(_) => true
    _ => false
  } noraise {
    _ => false
  }
  assert_true(rejected)
}
