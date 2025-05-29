import Foundation

// MARK: - Shared Instance

private let sharedSAAE = SAAE()

// MARK: - Public API Functions

/// Parse Swift code from a file URL
/// - Parameter url: URL pointing to a local Swift source file
/// - Returns: AST handle for the parsed code
/// - Throws: SAAEError if file cannot be read or parsed
public func parse(url: URL) throws -> ASTHandle {
    return try sharedSAAE.parse(url: url)
}

/// Parse Swift code from a string
/// - Parameter string: String containing Swift source code
/// - Returns: AST handle for the parsed code
/// - Throws: SAAEError if code cannot be parsed
public func parse(string: String) throws -> ASTHandle {
    return try sharedSAAE.parse(string: string)
}

/// Generate an overview of declarations in the parsed AST
/// - Parameters:
///   - astHandle: The AST handle obtained from a parse operation
///   - format: Output format (.json, .yaml, .markdown, .interface)
///   - minVisibility: Minimum visibility level to include
/// - Returns: String containing the generated overview
/// - Throws: SAAEError if AST handle is invalid
public func generateOverview(
    astHandle: ASTHandle,
    format: OutputFormat = .json,
	minVisibility: SAAE.VisibilityLevel = .internal
) throws -> String {
    return try sharedSAAE.generateOverview(
        astHandle: astHandle,
        format: format,
        minVisibility: minVisibility
    )
}

/// Generate an overview of declarations in multiple parsed ASTs
/// - Parameters:
///   - astHandlesWithPaths: Array of tuples containing AST handles and their file paths
///   - format: Output format (.json, .yaml, .markdown, .interface)
///   - minVisibility: Minimum visibility level to include
/// - Returns: String containing the generated overview
/// - Throws: SAAEError if any AST handle is invalid
public func generateMultiFileOverview(
    astHandlesWithPaths: [(handle: ASTHandle, path: String)],
    format: OutputFormat = .json,
	minVisibility: SAAE.VisibilityLevel = .internal
) throws -> String {
    return try sharedSAAE.generateMultiFileOverview(
        astHandlesWithPaths: astHandlesWithPaths,
        format: format,
        minVisibility: minVisibility
    )
} 
