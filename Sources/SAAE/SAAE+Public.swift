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
///   - format: Output format (.json, .yaml, .markdown)
///   - minVisibility: Minimum visibility level to include
/// - Returns: String containing the generated overview
/// - Throws: SAAEError if AST handle is invalid
public func generateOverview(
    astHandle: ASTHandle,
    format: OutputFormat = .json,
    minVisibility: VisibilityLevel = .internal
) throws -> String {
    return try sharedSAAE.generateOverview(
        astHandle: astHandle,
        format: format,
        minVisibility: minVisibility
    )
} 