import Foundation

// MARK: - Shared Instance

private let sharedSAAE = SAAE()

// MARK: - Public API Functions

/// Parse Swift code from a file URL
/// - Parameter fileURL: URL pointing to a local Swift source file
/// - Returns: AST handle for the parsed code
/// - Throws: SAAEError if file cannot be read or parsed
public func parse(from_url fileURL: URL) throws -> ASTHandle {
    return try sharedSAAE.parse(from_url: fileURL)
}

/// Parse Swift code from a string
/// - Parameter codeString: String containing Swift source code
/// - Returns: AST handle for the parsed code
/// - Throws: SAAEError if code cannot be parsed
public func parse(from_string codeString: String) throws -> ASTHandle {
    return try sharedSAAE.parse(from_string: codeString)
}

/// Generate an overview of declarations in the parsed AST
/// - Parameters:
///   - ast_handle: The AST handle obtained from a parse operation
///   - format: Output format (.json, .yaml, .markdown)
///   - min_visibility: Minimum visibility level to include
/// - Returns: String containing the generated overview
/// - Throws: SAAEError if AST handle is invalid
public func generate_overview(
    ast_handle: ASTHandle,
    format: OutputFormat = .json,
    min_visibility: VisibilityLevel = .internal
) throws -> String {
    return try sharedSAAE.generate_overview(
        ast_handle: ast_handle,
        format: format,
        min_visibility: min_visibility
    )
} 