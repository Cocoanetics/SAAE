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

/// Container structure for multi-file analysis results.
///
/// This structure organizes the results of analyzing multiple Swift files,
/// providing a top-level container for all file-specific overviews.
internal struct MultiFileCodeOverview: Codable {
    /// Array of individual file analysis results.
    internal let files: [FileOverview]
    
    /// Creates a multi-file overview from individual file results.
    ///
    /// - Parameter files: Array of file overview results.
    internal init(files: [FileOverview]) {
        self.files = files
    }
}

/// Represents a comprehensive overview of a single Swift declaration.
///
/// This structure captures all relevant information about a Swift declaration including
/// its metadata, documentation, signature, and hierarchical relationships. It serves
/// as the fundamental building block for all SAAE analysis outputs.
///
/// ## Declaration Types
///
/// Supports all major Swift declaration types:
/// - Classes, structs, enums, protocols
/// - Functions, methods, initializers
/// - Properties (stored and computed)
/// - Type aliases, extensions
/// - Enum cases and associated values
///
/// ## Hierarchical Structure
///
/// Declarations can contain nested declarations through the ``members`` property,
/// allowing representation of complex Swift types with their contained elements.
///
/// ## Path-Based Navigation
///
/// Each declaration has a unique ``path`` that enables precise location within
/// the declaration hierarchy, useful for cross-references and navigation.
public struct DeclarationOverview: Codable {
    /// Unique path identifier for this declaration within the hierarchy.
    ///
    /// The path uses dot notation to represent nesting levels (e.g., "1.2.1").
    /// This enables precise navigation and cross-referencing within documentation.
    public let path: String
    
    /// The Swift declaration type (e.g., "class", "func", "var", "enum").
    ///
    /// This identifies what kind of Swift construct this declaration represents,
    /// used for formatting and categorization in output generation.
    public let type: String
    
    /// The simple name of the declaration.
    ///
    /// For most declarations, this is the identifier used in the source code.
    /// For operators and special methods, this may include the operator symbols.
    public let name: String
    
    /// The fully qualified name including parent context, if applicable.
    ///
    /// For nested declarations, this includes the parent names separated by dots
    /// (e.g., "MyClass.NestedStruct.someProperty"). For top-level declarations,
    /// this may be the same as ``name``.
    public let fullName: String?
    
    /// The complete declaration signature as it appears in source code.
    ///
    /// This includes parameter lists, return types, generic constraints,
    /// and other signature elements, but excludes the implementation body.
    public let signature: String?
    
    /// The access control level as a string (e.g., "public", "private").
    ///
    /// Represents the Swift visibility modifier that controls where
    /// this declaration can be accessed from.
    public let visibility: String
    
    /// Additional Swift modifiers applied to this declaration.
    ///
    /// Examples include "static", "final", "override", "async", "throws".
    /// Returns `nil` if no modifiers are present.
    public let modifiers: [String]?
    
    /// Swift attributes applied to this declaration.
    ///
    /// Examples include "@objc", "@available", "@propertyWrapper".
    /// Returns `nil` if no attributes are present.
    public let attributes: [String]?
    
    /// Structured documentation extracted from Swift documentation comments.
    ///
    /// Contains parsed information including description, parameters,
    /// return values, and throws information. Returns `nil` if no
    /// documentation is present.
    public let documentation: Documentation?
    
    /// Nested declarations contained within this declaration.
    ///
    /// For container types (classes, structs, enums, protocols), this contains
    /// their member declarations. Returns `nil` for simple declarations
    /// that cannot contain members.
    public let members: [DeclarationOverview]?
    
    /// Creates a declaration overview with comprehensive metadata.
    ///
    /// - Parameters:
    ///   - path: Unique hierarchical path identifier.
    ///   - type: Swift declaration type identifier.
    ///   - name: Simple declaration name.
    ///   - fullName: Fully qualified name with context.
    ///   - signature: Complete declaration signature.
    ///   - visibility: Access control level string.
    ///   - modifiers: Array of Swift modifiers.
    ///   - attributes: Array of Swift attributes.
    ///   - documentation: Parsed documentation structure.
    ///   - members: Nested declaration array.
    public init(
        path: String,
        type: String,
        name: String,
        fullName: String? = nil,
        signature: String? = nil,
        visibility: String,
        modifiers: [String]? = nil,
        attributes: [String]? = nil,
        documentation: Documentation? = nil,
        members: [DeclarationOverview]? = nil
    ) {
        self.path = path
        self.type = type
        self.name = name
        self.fullName = fullName
        self.signature = signature
        self.visibility = visibility
        self.modifiers = modifiers
        self.attributes = attributes
        self.documentation = documentation
        self.members = members
    }
}

// MARK: - Declaration Overview Metadata

// MARK: - Path-Based Navigation

internal struct PathNavigator {
    internal static func findDeclaration(at path: String, in declarations: [DeclarationOverview]) -> DeclarationOverview? {
        let components = path.split(separator: ".").map(String.init)
        return findDeclarationRecursive(components: components, in: declarations)
    }
    
    private static func findDeclarationRecursive(components: [String], in declarations: [DeclarationOverview]) -> DeclarationOverview? {
        guard let firstComponent = components.first else { return nil }
        
        if let targetIndex = Int(firstComponent), targetIndex > 0 && targetIndex <= declarations.count {
            let target = declarations[targetIndex - 1]
            
            if components.count == 1 {
                return target
            } else {
                let remainingComponents = Array(components.dropFirst())
                return target.members.flatMap { findDeclarationRecursive(components: remainingComponents, in: $0) }
            }
        }
        
        return nil
    }
} 