///|
/// Small field matrix used only for codec construction and erasure recovery.
pub struct Matrix {
  rows : Int
  cols : Int
  cells : Array[Array[Int]]
}

///|
fn Matrix::zero(rows : Int, cols : Int) -> Matrix {
  let cells : Array[Array[Int]] = []
  for row = 0; row < rows; row = row + 1 {
    cells.push(Array::make(cols, 0))
  }
  { rows, cols, cells }
}

///|
fn Matrix::top_square(self : Matrix, size : Int) -> Matrix {
  let result = Matrix::zero(size, size)
  for row = 0; row < size; row = row + 1 {
    for col = 0; col < size; col = col + 1 {
      result.cells[row][col] = self.cells[row][col]
    }
  }
  result
}

///|
fn Matrix::selected_rows(self : Matrix, indices : Array[Int]) -> Matrix {
  let result = Matrix::zero(indices.length(), self.cols)
  for row = 0; row < indices.length(); row = row + 1 {
    for col = 0; col < self.cols; col = col + 1 {
      result.cells[row][col] = self.cells[indices[row]][col]
    }
  }
  result
}

///|
fn Matrix::multiply(self : Matrix, other : Matrix, field : Field) -> Matrix {
  let result = Matrix::zero(self.rows, other.cols)
  for row = 0; row < self.rows; row = row + 1 {
    for inner = 0; inner < self.cols; inner = inner + 1 {
      let coefficient = self.cells[row][inner]
      if coefficient != 0 {
        for col = 0; col < other.cols; col = col + 1 {
          result.cells[row][col] = result.cells[row][col] ^
            field.multiply(coefficient, other.cells[inner][col])
        }
      }
    }
  }
  result
}

///|
/// Gauss-Jordan elimination. The input remains unchanged.
fn Matrix::inverse(self : Matrix, field : Field) -> Matrix raise ErasureError {
  if self.rows != self.cols || self.rows < 1 {
    raise SingularMatrix
  }
  let size = self.rows
  let width = size * 2
  let augmented = Matrix::zero(size, width)
  for row = 0; row < size; row = row + 1 {
    for col = 0; col < size; col = col + 1 {
      augmented.cells[row][col] = self.cells[row][col]
    }
    augmented.cells[row][size + row] = 1
  }
  for col = 0; col < size; col = col + 1 {
    let mut pivot = col
    while pivot < size && augmented.cells[pivot][col] == 0 {
      pivot = pivot + 1
    }
    if pivot == size {
      raise SingularMatrix
    }
    if pivot != col {
      let old = augmented.cells[col]
      augmented.cells[col] = augmented.cells[pivot]
      augmented.cells[pivot] = old
    }
    let divisor = augmented.cells[col][col]
    let reciprocal = field.inverse(divisor)
    for cell = 0; cell < width; cell = cell + 1 {
      augmented.cells[col][cell] = field.multiply(
        augmented.cells[col][cell],
        reciprocal,
      )
    }
    for row = 0; row < size; row = row + 1 {
      if row != col {
        let factor = augmented.cells[row][col]
        if factor != 0 {
          for cell = 0; cell < width; cell = cell + 1 {
            augmented.cells[row][cell] = augmented.cells[row][cell] ^
              field.multiply(factor, augmented.cells[col][cell])
          }
        }
      }
    }
  }
  let result = Matrix::zero(size, size)
  for row = 0; row < size; row = row + 1 {
    for col = 0; col < size; col = col + 1 {
      result.cells[row][col] = augmented.cells[row][size + col]
    }
  }
  result
}

///|
fn vandermonde(rows : Int, cols : Int, field : Field) -> Matrix {
  let result = Matrix::zero(rows, cols)
  for row = 0; row < rows; row = row + 1 {
    for col = 0; col < cols; col = col + 1 {
      result.cells[row][col] = field.power(row, col)
    }
  }
  result
}

///|
fn systematic_matrix(
  data_count : Int,
  total_count : Int,
  field : Field,
) -> Matrix raise ErasureError {
  let raw = vandermonde(total_count, data_count, field)
  let normalizer = raw.top_square(data_count).inverse(field)
  raw.multiply(normalizer, field)
}
