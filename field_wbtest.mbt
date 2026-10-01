///|
test "field multiplication and inverses cover every nonzero byte" {
  let field = Field::new()
  assert_eq(field.multiply(0, 255), 0)
  assert_eq(field.multiply(1, 173), 173)
  for value = 1; value < 256; value = value + 1 {
    let inverse = try! field.inverse(value)
    assert_eq(field.multiply(value, inverse), 1)
  }
}

///|
test "field powers and multiplication are consistent" {
  let field = Field::new()
  assert_eq(field.power(0, 0), 1)
  assert_eq(field.power(0, 3), 0)
  for left = 1; left < 256; left = left + 1 {
    for right = 1; right < 256; right = right + 1 {
      assert_eq(field.multiply(left, right), field.multiply(right, left))
    }
    assert_eq(field.power(left, 2), field.multiply(left, left))
  }
}
