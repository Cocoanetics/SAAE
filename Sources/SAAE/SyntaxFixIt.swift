import Foundation
import SwiftDiagnostics
import SwiftParser
import SwiftParserDiagnostics
import SwiftSyntax

/**
 A suggested fix for a syntax error with specific text replacement information.
 */
public struct SyntaxFixIt {
    /// Human-readable description of what the fix does
    public let message: String
    
    /// The original text to be replaced
    public let originalText: String
    
    /// The suggested replacement text
    public let replacementText: String
    
    /// Source location range for the replacement
    public let range: SourceLocation
}
