///|
test "CRC32C standard check value" {
  assert_eq(@moonerasure.crc32c(b"123456789"), 0xe3069283U)
  assert_eq(@moonerasure.crc32c(b""), 0U)
}
