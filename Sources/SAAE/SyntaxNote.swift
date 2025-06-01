import Foundation
import SwiftDiagnostics
import SwiftParser
import SwiftParserDiagnostics
import SwiftSyntax

/**
 Additional contextual information about a syntax error.
 */
public struct SyntaxNote {
/// The note's message
    public let message: String

/// Source location where this note applies
    public let location: SourceLocation?

/// The source line for this note's location
    public let sourceLineText: String?
}
