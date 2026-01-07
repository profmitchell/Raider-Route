import CoreGraphics
import Foundation

struct CalibrationLogic {
  /// Solves for affine transform coefficients:
  /// x = a*lat + b*lng + tx
  /// y = c*lat + d*lng + ty
  ///
  /// Requires at least 3 anchors.
  static func solve(anchors: [CalibrationAnchor]) -> [Double]? {
    guard anchors.count >= 3 else { return nil }

    // We're solving two systems of linear equations:
    // 1) X = A * Lat + B * Lng + Tx
    // 2) Y = C * Lat + D * Lng + Ty

    // Using basic linear least squares or direct solution if simple enough.
    // For robustness with >3 points, we'd want Least Squares.
    // Given complexity constraints, we'll try a simple 3-point exact solution using the first 3 valid points.
    // Or if we want to be fancy, we can implement a mini-Gaussian elimination.

    // Let's implement a tailored least squares for 6 unknowns (a,b,tx) and (c,d,ty) independently.
    // Problem: minimize Σ(x_i - (a*lat_i + b*lng_i + tx))^2

    // This is equivalent to solving M * [a, b, tx]^T = X_vec
    // Where M is row: [lat, lng, 1]

    let (a, b, tx) = fitPlane(anchors: anchors) { ($0.lat, $0.lng, $0.x) }
    let (c, d, ty) = fitPlane(anchors: anchors) { ($0.lat, $0.lng, $0.y) }

    return [a, b, c, d, tx, ty]
  }

  // Fits Z = A*X + B*Y + C
  // Returns (A, B, C)
  private static func fitPlane(
    anchors: [CalibrationAnchor], extractor: (CalibrationAnchor) -> (Double, Double, Double)
  ) -> (Double, Double, Double) {
    // M^T * M * Beta = M^T * Y
    // M rows are [lat, lng, 1]

    var sumLat2 = 0.0
    var sumLng2 = 0.0
    var sumLatLng = 0.0
    var sumLat = 0.0
    var sumLng = 0.0

    var sumXLat = 0.0
    var sumXLng = 0.0
    var sumX = 0.0

    let n = Double(anchors.count)

    for p in anchors {
      let (lat, lng, val) = extractor(p)
      sumLat2 += lat * lat
      sumLng2 += lng * lng
      sumLatLng += lat * lng
      sumLat += lat
      sumLng += lng

      sumXLat += val * lat
      sumXLng += val * lng
      sumX += val
    }

    // 3x3 Matrix components for (M^T * M)
    // | sumLat2   sumLatLng sumLat |
    // | sumLatLng sumLng2   sumLng |
    // | sumLat    sumLng    n      |

    let m11 = sumLat2
    let m12 = sumLatLng
    let m13 = sumLat
    let m21 = sumLatLng
    let m22 = sumLng2
    let m23 = sumLng
    let m31 = sumLat
    let m32 = sumLng
    let m33 = n

    // Determinant
    let det =
      m11 * (m22 * m33 - m23 * m32) - m12 * (m21 * m33 - m23 * m31) + m13 * (m21 * m32 - m22 * m31)

    if abs(det) < 1e-9 { return (1, 0, 0) }  // Singularity fallback

    // Inverse * RHS vector (sumXLat, sumXLng, sumX)
    // We only need the solution, not full inverse.
    // Using Cramer's rule or cofactor expansion here is tedious but straightforward for 3x3.
    // Beta_0 (a)
    let detA =
      sumXLat * (m22 * m33 - m23 * m32) - m12 * (sumXLng * m33 - m23 * sumX) + m13
      * (sumXLng * m32 - m22 * sumX)

    // Beta_1 (b)
    let detB =
      m11 * (sumXLng * m33 - m23 * sumX) - sumXLat * (m21 * m33 - m23 * m31) + m13
      * (m21 * sumX - sumXLng * m31)

    // Beta_2 (c/tx)
    let detC =
      m11 * (m22 * sumX - sumXLng * m32) - m12 * (m21 * sumX - sumXLng * m31) + sumXLat
      * (m21 * m32 - m22 * m31)

    return (detA / det, detB / det, detC / det)
  }

  static func project(lat: Double, lng: Double, transform: [Double]) -> CGPoint {
    guard transform.count == 6 else { return .zero }
    let a = transform[0]
    let b = transform[1]
    let c = transform[2]
    let d = transform[3]
    let tx = transform[4]
    let ty = transform[5]

    let x = a * lat + b * lng + tx
    let y = c * lat + d * lng + ty
    return CGPoint(x: x, y: y)
  }
}
