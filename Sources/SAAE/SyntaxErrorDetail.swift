import Foundation
import SwiftDiagnostics
import SwiftParser
import SwiftParserDiagnostics
import SwiftSyntax

// MARK: - Phase 2: Syntax Error Detection and Reporting

/**
 Detailed information about a syntax error found in Swift source code.
 
 This structure provides comprehensive error reporting including location,
 context, suggested fixes, and visual indicators for precise error identification.
 */
public struct SyntaxErrorDetail {
/// The main error message describing what went wrong
    public let message: String

/// Source location information with line/column positions
    public let location: SourceLocation

/// The actual line of source code containing the error
    public let sourceLineText: String

/// Visual caret line pointing to the exact error location
    public let caretLineText: String

/// Surrounding source lines for context (typically 1-2 lines above/below)
    public let sourceContext: [String]

/// Range of lines shown in sourceContext (e.g., "3-5")
    public let contextRange: String

/// Available fix-it suggestions for automatically correcting the error
    public let fixIts: [SyntaxFixIt]

/// Additional notes providing more context about the error
    public let notes: [SyntaxNote]

/// The raw Swift syntax node that caused the error
    public let affectedNode: Syntax
}
