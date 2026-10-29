///|
test "costed fetch selects cheaper parity basis and actually recovers the target" {
  let codec = @moonerasure.Codec::new(3, 2)
  let all = codec.encode_all([b"abc", b"def", b"ghi"])
  let costed = codec.plan_costed([true, true, true, true, true], [
    100L, 80L, 2L, 1L, 1L,
  ])
  assert_eq(costed.plan().selected_indices(), [3, 4, 2])
  assert_eq(costed.total_cost(), 4L)
  let supplied : Array[Bytes?] = Array::make(5, None)
  for i in costed.plan().selected_indices() {
    supplied[i] = Some(all[i])
  }
  assert_eq(codec.reconstruct_selected(supplied, [0])[0], b"abc")
  let detached = costed.plan().selected_indices()
  detached.clear()
  assert_eq(costed.plan().selected_indices().length(), 3)
}

///|
test "costed plan reports shortfall ties invalid inputs and overflow" {
  let codec = @moonerasure.Codec::new(2, 2)
  assert_eq(
    codec
    .plan_costed([true, true, true, true], [1L, 1L, 1L, 1L])
    .plan()
    .selected_indices(),
    [0, 1],
  )
  let short = codec.plan_costed([false, false, true, false], [0L, 0L, 7L, 0L])
  assert_eq(short.plan().minimum_additional_shards(), 1)
  assert_eq(short.total_cost(), 7L)
  let bad = try {
    ignore(codec.plan_costed([true, true, true, true], [1L, -1L, 0L, 0L]))
    false
  } catch {
    _ => true
  }
  assert_true(bad)
  let overflow = try {
    ignore(
      codec.plan_costed([true, true, false, false], [
        9223372036854775807L, 1L, 0L, 0L,
      ]),
    )
    false
  } catch {
    _ => true
  }
  assert_true(overflow)
}

///|
test "domain exposure combines current erasures with one rack outage deterministically" {
  let codec = @moonerasure.Codec::new(3, 2)
  let risk = codec.assess_domains([true, true, true, true, false], [
    "rack-a", "rack-a", "rack-b", "rack-c", "rack-c",
  ])
  assert_eq(risk[0].domain(), "rack-a")
  assert_eq(risk[0].spare(), -1)
  assert_false(risk[0].recoverable())
  assert_eq(risk[1].spare(), 0)
  assert_true(risk[1].recoverable())
  assert_eq(risk[2].lost_available(), 1)
  let invalid = try {
    ignore(
      codec.assess_domains([true, true, true, true, true], [
        "a", "b", "", "c", "d",
      ]),
    )
    false
  } catch {
    _ => true
  }
  assert_true(invalid)
}
