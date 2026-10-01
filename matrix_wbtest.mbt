///|
test "matrix inverse handles a zero diagonal by swapping rows" {
  let field = Field::new()
  let matrix = Matrix::zero(2, 2)
  matrix.cells[0][0] = 0
  matrix.cells[0][1] = 1
  matrix.cells[1][0] = 1
  matrix.cells[1][1] = 1
  let inverse = try! matrix.inverse(field)
  let identity = Matrix::zero(2, 2)
  identity.cells[0][0] = 1
  identity.cells[1][1] = 1
  assert_eq(matrix.multiply(inverse, field).cells, identity.cells)
}

///|
test "singular matrix is rejected" {
  let field = Field::new()
  let matrix = Matrix::zero(2, 2)
  matrix.cells[0][0] = 1
  matrix.cells[0][1] = 1
  matrix.cells[1][0] = 1
  matrix.cells[1][1] = 1
  let rejected = try matrix.inverse(field) catch {
    SingularMatrix => true
    _ => false
  } noraise {
    _ => false
  }
  assert_true(rejected)
}

///|
test "systematic matrix keeps source shards in its first rows" {
  let field = Field::new()
  for data_count = 1; data_count <= 8; data_count = data_count + 1 {
    let matrix = try! systematic_matrix(data_count, data_count + 3, field)
    for row = 0; row < data_count; row = row + 1 {
      for col = 0; col < data_count; col = col + 1 {
        assert_eq(matrix.cells[row][col], if row == col { 1 } else { 0 })
      }
    }
  }
}
