///|
test "two checksum failures become known erasures" {
  let codec = try! @moonerasure.Codec::new(3, 2)
  let frames = try! @moonerasure.encode_stripe(codec, b"packet loss example", 6, 2)
  let raw : Array[Bytes] = []
  for index = 0; index < frames.length(); index = index + 1 {
    let bytes = frames[index].to_bytes().to_array()
    if index == 0 || index == 4 {
      bytes[32] = (bytes[32].to_int() ^ 1).to_byte()
    }
    raw.push(Bytes::from_array(bytes))
  }
  let result = try! @moonerasure.recover_serialized_stripe(codec, raw, 6, 2)
  assert_eq(result.recovery().payload(), b"packet loss example")
  assert_eq(result.recovery().missing_indices(), [0, 4])
  assert_eq(result.issues().length(), 2)
  assert_eq(result.issues()[0].source_position(), 0)
  assert_eq(result.issues()[0].code(), "ERASURE_CHECKSUM")
}

///|
test "scanner rejects malformed frame without dropping a good neighbor" {
  let codec = try! @moonerasure.Codec::new(2, 1)
  let frames = try! @moonerasure.encode_stripe(codec, b"good", 2, 0)
  let scan = try! @moonerasure.scan_frames([b"garbage", frames[0].to_bytes()])
  assert_eq(scan.valid_count(), 1)
  assert_eq(scan.rejected_count(), 1)
  assert_eq(scan.issues()[0].source_position(), 0)
}
