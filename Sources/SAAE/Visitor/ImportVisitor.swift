import Foundation
import SwiftSyntax

/// A syntax visitor that collects import statements from Swift source files.
///
/// `ImportVisitor` traverses the syntax tree and extracts all import declarations,
/// storing them as a list of module names. This is useful for understanding
/// the dependencies of a Swift file and generating comprehensive overviews.
///
/// ## Usage
///
/// ```swift
/// let visitor = ImportVisitor()
/// visitor.walk(syntaxTree.sourceFile)
/// print(visitor.imports) // ["Foundation", "SwiftUI", "Combine"]
/// ```
///
/// ## Supported Import Formats
///
/// The visitor handles various import statement formats:
/// - Simple imports: `import Foundation`
/// - Submodule imports: `import SwiftUI.Animation`
/// - Specific symbol imports: `import Foundation.Date` (captured as "Foundation.Date")
///
/// - Note: The visitor extracts the full import path including submodules and specific symbols.
internal class ImportVisitor: SyntaxVisitor {
    /// Array containing all discovered import statements.
    ///
    /// Each string represents a complete import path (e.g., "Foundation", "SwiftUI.Animation").
    /// The imports are collected in the order they appear in the source file.
    var imports: [String] = []
    
    /// Creates an import visitor with the specified syntax tree view mode.
    ///
    /// - Parameter viewMode: The view mode for syntax tree traversal.
    override init(viewMode: SyntaxTreeViewMode) {
        super.init(viewMode: viewMode)
    }
    
    /// Creates an import visitor with source-accurate view mode.
    ///
    /// This is the most commonly used initializer, providing accurate representation
    /// of the original source file including whitespace and comments.
    convenience init() {
        self.init(viewMode: .sourceAccurate)
    }
    
    /// Visits an import declaration node and extracts the import path.
    ///
    /// This method is called automatically during syntax tree traversal when an
    /// import statement is encountered. It extracts the full module path and
    /// adds it to the ``imports`` array.
    ///
    /// - Parameter node: The import declaration syntax node.
    /// - Returns: `.visitChildren` to continue traversing child nodes.
    ///
    /// ## Implementation Details
    ///
    /// The method reconstructs the full import path by joining all path components
    /// with dots, handling cases like:
    /// - `import Foundation` → "Foundation"
    /// - `import SwiftUI.Animation` → "SwiftUI.Animation"
    override func visit(_ node: ImportDeclSyntax) -> SyntaxVisitorContinueKind {
        // Extract the import path
        let importPath = node.path.map { $0.name.text }.joined(separator: ".")
        imports.append(importPath)
        return .visitChildren
    }
}
