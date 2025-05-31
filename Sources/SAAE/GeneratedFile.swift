import Foundation
import SwiftSyntax

/// Represents a generated Swift source file
public struct GeneratedFile {
    /// The filename (including .swift extension)
    public let fileName: String
    
    /// The complete source code content
    public let content: String
    
    /// The import statements included in this file
    public let imports: [String]
    
    /// The declarations included in this file
    public let declarations: [DeclarationOverview]
    
    public init(fileName: String, content: String, imports: [String], declarations: [DeclarationOverview]) {
        self.fileName = fileName
        self.content = content
        self.imports = imports
        self.declarations = declarations
    }
}
