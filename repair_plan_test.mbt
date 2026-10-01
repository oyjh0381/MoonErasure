///|
test "repair plan identifies shortage and chosen shards" {
  let codec = try! @moonerasure.Codec::new(3, 2)
  let shortage = try! codec.plan([false, true, false, true, false])
  assert_false(shortage.recoverable())
  assert_eq(shortage.available(), 2)
  assert_eq(shortage.minimum_additional_shards(), 1)
  assert_eq(shortage.missing_data_indices(), [0, 2])
  assert_eq(shortage.missing_parity_indices(), [4])
  assert_true(shortage.needs_decode())
  let sufficient = try! codec.plan([false, true, false, true, true])
  assert_true(sufficient.recoverable())
  assert_eq(sufficient.selected_indices(), [1, 3, 4])
  assert_eq(sufficient.minimum_additional_shards(), 0)
}

///|
test "repair plan keeps direct data path separate from decoding" {
  let codec = try! @moonerasure.Codec::new(2, 2)
  let plan = try! codec.plan([true, true, false, false])
  assert_true(plan.recoverable())
  assert_false(plan.needs_decode())
  assert_eq(plan.missing_parity_indices(), [2, 3])
}
