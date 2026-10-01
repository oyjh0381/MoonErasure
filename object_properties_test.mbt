///|
test "object round trips across empty partial and exact stripes" {
  for data_count = 1; data_count <= 5; data_count = data_count + 1 {
    for parity_count = 1; parity_count <= 3; parity_count = parity_count + 1 {
      let codec = try! @moonerasure.Codec::new(data_count, parity_count)
      for stripe_limit in [1, 3, 8, 17] {
        for total_length in [0, 1, 2, 7, 8, 9, 16, 17, 31] {
          let payload = Array::make(total_length, b'\x00')
          for index = 0; index < total_length; index = index + 1 {
            payload[index] = ((index * 19 + data_count * 43 + parity_count) % 256).to_byte()
          }
          let source = Bytes::from_array(payload)
          let object = try! @moonerasure.encode_object(
            codec,
            source,
            88,
            stripe_payload_limit=stripe_limit,
          )
          let retained : Array[@moonerasure.ShardEnvelope] = []
          for frame in object.frames() {
            if frame.shard_index() != frame.stripe_index() %
              (data_count + parity_count) {
              retained.push(frame)
            }
          }
          let result = try! @moonerasure.recover_object(
            object.manifest(),
            retained,
          )
          assert_eq(result.payload(), source)
          if total_length == 0 {
            assert_eq(result.stripe_count(), 0)
          } else {
            assert_eq(
              result.stripe_count(),
              (total_length - 1) / stripe_limit + 1,
            )
          }
        }
      }
    }
  }
}

///|
test "every valid byte range matches direct slice after frame loss" {
  let codec = try! @moonerasure.Codec::new(4, 2)
  let payload = b"0123456789abcdefghijKLMNOPQRSTuvwxyz!@#$"
  let object = try! @moonerasure.encode_object(
    codec,
    payload,
    91,
    stripe_payload_limit=7,
  )
  let retained : Array[@moonerasure.ShardEnvelope] = []
  for frame in object.frames() {
    if frame.shard_index() != (frame.stripe_index() % 2) {
      retained.push(frame)
    }
  }
  for start = 0; start <= payload.length(); start = start + 1 {
    for end = start; end <= payload.length(); end = end + 1 {
      let recovered = try! @moonerasure.recover_object_range(
        object.manifest(),
        retained,
        start,
        end - start,
      )
      assert_eq(recovered, Bytes::from_array(payload[start:end].to_array()))
    }
  }
}
