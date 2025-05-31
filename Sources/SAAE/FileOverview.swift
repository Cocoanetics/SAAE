import Foundation

/// Represents a single Swift file's analysis results with path information for multi-file processing.
///
/// This structure is used when analyzing multiple files to maintain file-level organization
/// and provide context about which file each declaration belongs to.
internal struct FileOverview: Codable {
    /// The file system path to the analyzed Swift file.
    internal let path: String
    
    /// All import statements found in this file.
    internal let imports: [String]
    
    /// All declarations found in this file.
    internal let declarations: [DeclarationOverview]
    
    /// Creates a file overview with path and analysis results.
    ///
    /// - Parameters:
    ///   - path: The file system path to the Swift file.
    ///   - imports: Array of import statements from the file.
    ///   - declarations: Array of declarations found in the file.
    internal init(path: String, imports: [String], declarations: [DeclarationOverview]) {
        self.path = path
        self.imports = imports
        self.declarations = declarations
    }
}
