public enum NodeOperationError: Error, CustomStringConvertible, Equatable {
    case nodeNotFound(path: String)
    case invalidInsertionPoint(reason: String)
    case invalidReplacementContext(reason: String)
    case astModificationFailed(reason: String)

    public var description: String {
        switch self {
        case .nodeNotFound(let path): return "Node not found at path: \(path)"
        case .invalidInsertionPoint(let reason): return "Invalid insertion point: \(reason)"
        case .invalidReplacementContext(let reason): return "Invalid replacement context: \(reason)"
        case .astModificationFailed(let reason): return "AST modification failed: \(reason)"
        }
    }

    public static func == (lhs: NodeOperationError, rhs: NodeOperationError) -> Bool {
        switch (lhs, rhs) {
        case (.nodeNotFound(let p1), .nodeNotFound(let p2)): return p1 == p2
        case (.invalidInsertionPoint(let r1), .invalidInsertionPoint(let r2)): return r1 == r2
        case (.invalidReplacementContext(let r1), .invalidReplacementContext(let r2)): return r1 == r2
        case (.astModificationFailed(let r1), .astModificationFailed(let r2)): return r1 == r2
        default: return false
        }
    }
} 