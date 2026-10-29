///|
fn main raise {
  let codec = @ec.Codec::new(3, 2)
  let encoded = codec.encode_all([b"block-a", b"block-b", b"block-c"])
  let plan = codec.plan_costed([true, true, true, true, true], [
    100L, 80L, 2L, 1L, 1L,
  ])
  let fetched : Array[Bytes?] = Array::make(5, None)
  for i in plan.plan().selected_indices() {
    fetched[i] = Some(encoded[i])
  }
  assert_eq(codec.reconstruct_selected(fetched, [0])[0], b"block-a")
  let risks = codec.assess_domains([true, true, true, true, false], [
    "rack-a", "rack-a", "rack-b", "rack-c", "rack-c",
  ])
  assert_false(risks[0].recoverable())
  println(
    "Cost-aware fetch reconstructs the requested block; correlated rack loss exposes insufficient surviving shards",
  )
}
