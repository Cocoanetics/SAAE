import Foundation
import SwiftSyntax

/// Visitor for collecting import statements from Swift source files
class ImportVisitor: SyntaxVisitor {
    var imports: [String] = []
    
    override init(viewMode: SyntaxTreeViewMode) {
        super.init(viewMode: viewMode)
    }
    
    convenience init() {
        self.init(viewMode: .sourceAccurate)
    }
    
    override func visit(_ node: ImportDeclSyntax) -> SyntaxVisitorContinueKind {
        // Extract the import path
        let importPath = node.path.map { $0.name.text }.joined(separator: ".")
        imports.append(importPath)
        return .visitChildren
    }
} 