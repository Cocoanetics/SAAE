import Foundation

extension VisibilityLevel: Comparable {
/// Compares two visibility levels based on their restrictiveness.
///
/// - Parameters:
///   - lhs: The left-hand side visibility level.
///   - rhs: The right-hand side visibility level.
/// - Returns: `true` if the left visibility level is more restrictive than the right one.
    public static func < (lhs: VisibilityLevel, rhs: VisibilityLevel) -> Bool {
        return allCases.firstIndex(of: lhs)! < allCases.firstIndex(of: rhs)!
    }
}
