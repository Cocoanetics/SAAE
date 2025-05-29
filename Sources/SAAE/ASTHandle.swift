import Foundation

/// Opaque handle for a parsed AST
public struct ASTHandle {
    internal let id: UUID
    
    internal init() {
        self.id = UUID()
    }
} 