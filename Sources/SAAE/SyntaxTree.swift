import Foundation
import SwiftSyntax
import SwiftParser
import SwiftDiagnostics
import SwiftParserDiagnostics

/// A wrapper around SwiftSyntax's SourceFileSyntax for easier manipulation and analysis.
///
/// `SyntaxTree` provides a convenient interface for parsing Swift source code from files or strings
/// and accessing the underlying SwiftSyntax representation. It handles file I/O operations and
/// provides appropriate error handling for common parsing scenarios.
///
/// ## Usage
///
/// ### Creating from a file:
/// ```swift
/// let tree = try SyntaxTree(url: URL(fileURLWithPath: "MyFile.swift"))
/// ```
///
/// ### Creating from source code:
/// ```swift
/// let sourceCode = """
/// class MyClass {
///     func myMethod() {}
/// }
/// """
/// let tree = try SyntaxTree(string: sourceCode)
/// ```
///
/// - Important: The parsed syntax tree is read-only. For code modifications, use SwiftSyntax's transformation APIs directly.
public struct SyntaxTree {
    
    /// The underlying SwiftSyntax source file representation.
    ///
    /// This property provides direct access to the parsed SwiftSyntax tree for advanced operations
    /// that require working with the raw syntax nodes.
    internal let sourceFile: SourceFileSyntax
    
    /// Pre-split source lines for efficient error context extraction
    private let sourceLines: [String]
    
    /// Source location converter for position mapping
    private let locationConverter: SourceLocationConverter
    
    /// Creates a syntax tree by parsing a Swift source file from disk.
    ///
    /// - Parameter url: The URL of the Swift source file to parse
    /// - Throws: SAAEError if the file cannot be read or parsed
    public init(url: URL) throws {
        do {
            let string = try String(contentsOf: url)
            self.sourceFile = Parser.parse(source: string)
            self.sourceLines = string.split(separator: "\n").map { String($0) }
            self.locationConverter = SourceLocationConverter(fileName: url.lastPathComponent, tree: self.sourceFile)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            throw SAAEError.fileNotFound(url)
        } catch {
            throw SAAEError.fileReadError(url, error)
        }
    }
    
    /// Creates a syntax tree by parsing Swift source code from a string.
    ///
    /// - Parameter string: The Swift source code to parse
    /// - Throws: SAAEError if code cannot be parsed
    public init(string: String) throws {
        self.sourceFile = Parser.parse(source: string)
        self.sourceLines = string.split(separator: "\n").map { String($0) }
        self.locationConverter = SourceLocationConverter(fileName: "source.swift", tree: self.sourceFile)
    }
    
    // MARK: - Phase 2: Syntax Error Detection
    
    /**
     All syntax errors found in the parsed source code.
     
     This property analyzes the syntax tree and extracts detailed information about
     any syntax errors discovered during parsing. Each error includes location,
     context, suggested fixes, and visual indicators.
     
     - Returns: An array of SyntaxErrorDetail objects, empty if no errors found
     */
    public var syntaxErrors: [SyntaxErrorDetail] {
        let diagnostics = ParseDiagnosticsGenerator.diagnostics(for: sourceFile)
        return diagnostics.map { diagnostic in
            SyntaxErrorDetail(from: diagnostic, sourceLines: sourceLines, converter: locationConverter)
        }
    }
    
    /**
     Checks if the source code has any syntax errors.
     
     - Returns: true if syntax errors were found, false if the code is syntactically valid
     */
    public var hasSyntaxErrors: Bool {
        return !syntaxErrors.isEmpty
    }
    
    /**
     Returns a count of syntax errors found in the source.
     
     - Returns: The number of syntax errors detected
     */
    public var syntaxErrorCount: Int {
        return syntaxErrors.count
    }
} 

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

extension SyntaxErrorDetail {
    /**
     Creates a SyntaxErrorDetail from a SwiftDiagnostics Diagnostic.
     
     This initializer implements the user's feedback:
     - Stores fullSourceText as lines for fast access
     - Uses SourceLocationConverter for line content extraction
     - Handles edge cases with bounds checking
     - Generates visual caret indicators
     
     - Parameters:
       - diagnostic: The diagnostic from SwiftParserDiagnostics
       - sourceLines: Pre-split source code lines for efficient access
       - converter: SourceLocationConverter for position mapping
     */
    public init(from diagnostic: Diagnostic, sourceLines: [String], converter: SourceLocationConverter) {
        // Basic diagnostic information
        self.message = diagnostic.message
        
        // Use direct byte offset for more accurate positioning
        let byteOffset = diagnostic.position
        self.location = converter.location(for: byteOffset)
        self.affectedNode = diagnostic.node
        
        // Extract source line text with bounds checking
        let lineIndex = self.location.line - 1 // Convert to 0-based index
        if lineIndex >= 0 && lineIndex < sourceLines.count {
            self.sourceLineText = sourceLines[lineIndex]
        } else {
            self.sourceLineText = "" // Edge case: invalid line number
        }
        
        // Generate visual caret line (e.g., "    ^")
        let caretPosition = max(0, self.location.column - 1) // Convert to 0-based, ensure non-negative
        self.caretLineText = String(repeating: " ", count: caretPosition) + "^"
        
        // Extract source context (lines around the error)
        let contextRadius = 1 // Show 1 line above and below
        let startLine = max(0, lineIndex - contextRadius)
        let endLine = min(sourceLines.count - 1, lineIndex + contextRadius)
        
        var contextLines: [String] = []
        // Ensure startLine <= endLine to avoid range errors
        if startLine <= endLine && endLine < sourceLines.count {
            for i in startLine...endLine {
                contextLines.append(sourceLines[i])
            }
        } else if lineIndex >= 0 && lineIndex < sourceLines.count {
            // Fallback: just include the error line itself
            contextLines.append(sourceLines[lineIndex])
        }
        self.sourceContext = contextLines
        
        // Calculate range string based on actual context lines used
        if contextLines.isEmpty {
            self.contextRange = "0-0" // No valid context
        } else if contextLines.count == 1 {
            self.contextRange = "\(lineIndex + 1)" // Just the error line
        } else {
            self.contextRange = "\(startLine + 1)-\(endLine + 1)" // Convert back to 1-based for display
        }
        
        // Process fix-its with SourceLocationConverter
        var fixIts: [SyntaxFixIt] = []
        for fixIt in diagnostic.fixIts {
            for change in fixIt.changes {
                switch change {
                case .replace(let oldNode, let newNode):
                    let fixItLocation = converter.location(for: oldNode.position)
                    let fix = SyntaxFixIt(
                        message: String(describing: fixIt.message),
                        originalText: oldNode.description.trimmingCharacters(in: .whitespacesAndNewlines),
                        replacementText: newNode.description.trimmingCharacters(in: .whitespacesAndNewlines),
                        range: fixItLocation
                    )
                    fixIts.append(fix)
                    
                case .replaceLeadingTrivia(let token, let newTrivia):
                    let fixItLocation = converter.location(for: token.position)
                    let fix = SyntaxFixIt(
                        message: String(describing: fixIt.message),
                        originalText: token.leadingTrivia.description,
                        replacementText: newTrivia.description,
                        range: fixItLocation
                    )
                    fixIts.append(fix)
                    
                case .replaceTrailingTrivia(let token, let newTrivia):
                    let fixItLocation = converter.location(for: token.endPositionBeforeTrailingTrivia)
                    let fix = SyntaxFixIt(
                        message: String(describing: fixIt.message),
                        originalText: token.trailingTrivia.description,
                        replacementText: newTrivia.description,
                        range: fixItLocation
                    )
                    fixIts.append(fix)
                    
                @unknown default:
                    // Handle any future fix-it types gracefully
                    let fixItLocation = self.location // Fallback to main diagnostic location
                    let fix = SyntaxFixIt(
                        message: String(describing: fixIt.message),
                        originalText: "",
                        replacementText: "",
                        range: fixItLocation
                    )
                    fixIts.append(fix)
                }
            }
        }
        self.fixIts = fixIts
        
        // Process notes
        var notes: [SyntaxNote] = []
        for note in diagnostic.notes {
            let noteLocation = converter.location(for: note.node.position)
            
            // Extract source line for the note with bounds checking
            let noteLineIndex = noteLocation.line - 1
            let noteSourceLine: String?
            if noteLineIndex >= 0 && noteLineIndex < sourceLines.count {
                noteSourceLine = sourceLines[noteLineIndex]
            } else {
                noteSourceLine = nil // Edge case: invalid line number
            }
            
            let syntaxNote = SyntaxNote(
                message: note.message,
                location: noteLocation,
                sourceLineText: noteSourceLine
            )
            notes.append(syntaxNote)
        }
        self.notes = notes
    }
} 
