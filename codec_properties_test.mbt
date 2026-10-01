///|
test "hand-computed systematic GF256 vector" {
  // For k=2 the normalized Vandermonde parity rows are [3,2] and [2,3].
  // GF256 products: 3*1 xor 2*2 = 7; 2*1 xor 3*2 = 4.
  let codec = try! @moonerasure.Codec::new(2, 2)
  let data : Array[Bytes] = [b"\x01", b"\x02"]
  let encoded = try! codec.encode_all(data)
  assert_eq(encoded, [b"\x01", b"\x02", b"\x07", b"\x04"])
  for first = 0; first < 4; first = first + 1 {
    for second = first + 1; second < 4; second = second + 1 {
      let retained : Array[Bytes?] = []
      for index = 0; index < 4; index = index + 1 {
        if index == first || index == second {
          retained.push(None)
        } else {
          retained.push(Some(encoded[index]))
        }
      }
      assert_eq(try! codec.reconstruct(retained), encoded)
    }
  }
}

///|
test "all single and double erasures recover across practical dimensions" {
  for data_count = 1; data_count <= 8; data_count = data_count + 1 {
    for parity_count = 1; parity_count <= 4; parity_count = parity_count + 1 {
      let codec = try! @moonerasure.Codec::new(data_count, parity_count)
      let source : Array[Bytes] = []
      for shard = 0; shard < data_count; shard = shard + 1 {
        let bytes = Array::make(31, b'\x00')
        for position = 0; position < bytes.length(); position = position + 1 {
          bytes[position] = ((shard * 37 + position * 17 + 199) % 256).to_byte()
        }
        source.push(Bytes::from_array(bytes))
      }
      let encoded = try! codec.encode_all(source)
      assert_true(try! codec.verify(encoded))
      for first = 0; first < encoded.length(); first = first + 1 {
        let one : Array[Bytes?] = []
        for index = 0; index < encoded.length(); index = index + 1 {
          if index == first {
            one.push(None)
          } else {
            one.push(Some(encoded[index]))
          }
        }
        assert_eq(try! codec.reconstruct(one), encoded)
        if parity_count >= 2 {
          for second = first + 1; second < encoded.length(); second = second + 1 {
            let two : Array[Bytes?] = []
            for index = 0; index < encoded.length(); index = index + 1 {
              if index == first || index == second {
                two.push(None)
              } else {
                two.push(Some(encoded[index]))
              }
            }
            assert_eq(try! codec.reconstruct(two), encoded)
          }
        }
      }
    }
  }
}

///|
test "deterministic three-erasure patterns recover with three parity shards" {
  let codec = try! @moonerasure.Codec::new(6, 3)
  let source : Array[Bytes] = []
  for shard = 0; shard < 6; shard = shard + 1 {
    let bytes = Array::make(19, b'\x00')
    for position = 0; position < 19; position = position + 1 {
      bytes[position] = ((shard * 53 + position * 29) % 256).to_byte()
    }
    source.push(Bytes::from_array(bytes))
  }
  let encoded = try! codec.encode_all(source)
  for first = 0; first < 9; first = first + 1 {
    for second = first + 1; second < 9; second = second + 1 {
      for third = second + 1; third < 9; third = third + 1 {
        let shards : Array[Bytes?] = []
        for index = 0; index < 9; index = index + 1 {
          if index == first || index == second || index == third {
            shards.push(None)
          } else {
            shards.push(Some(encoded[index]))
          }
        }
        assert_eq(try! codec.reconstruct(shards), encoded)
      }
    }
  }
}
