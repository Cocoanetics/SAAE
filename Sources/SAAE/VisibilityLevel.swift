import Foundation

/// Visibility levels for Swift declarations
public enum VisibilityLevel: Int, CaseIterable, Comparable {
    case `private` = 0
    case `fileprivate` = 1
    case `internal` = 2
    case `package` = 3
    case `public` = 4
    case `open` = 5
    
    public static func < (lhs: VisibilityLevel, rhs: VisibilityLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
    
    public var stringValue: String {
        switch self {
        case .private: return "private"
        case .fileprivate: return "fileprivate"
        case .internal: return "internal"
        case .package: return "package"
        case .public: return "public"
        case .open: return "open"
        }
    }
} 