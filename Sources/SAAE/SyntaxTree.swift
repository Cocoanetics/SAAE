import Foundation
import SwiftDiagnostics
import SwiftParser
import SwiftParserDiagnostics
import SwiftSyntax

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
    internal let sourceLines: [String]

/// Source location converter for position mapping
    internal let locationConverter: SourceLocationConverter

/// Creates a syntax tree by parsing a Swift source file from disk.
///
/// - Parameter url: The URL of the Swift source file to parse
/// - Throws: SAAEError if the file cannot be read or parsed
    public init(url: URL) throws {
        do {
        let string = try String(contentsOf: url)
        self.sourceFile = Parser.parse(source: string)
        self.locationConverter = SourceLocationConverter(fileName: url.lastPathComponent, tree: self.sourceFile)

// Get lines from SourceLocationConverter and strip any trailing newlines for consistency
        let rawLines = self.locationConverter.sourceLines
        self.sourceLines = rawLines.map { line in
// Strip trailing newline characters to match our previous string.split behavior
        return line.trimmingCharacters(in: .newlines)
    }
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
        self.locationConverter = SourceLocationConverter(fileName: "source.swift", tree: self.sourceFile)

// Get lines from SourceLocationConverter and strip any trailing newlines for consistency
        let rawLines = self.locationConverter.sourceLines
        self.sourceLines = rawLines.map { line in
// Strip trailing newline characters to match our previous string.split behavior
        return line.trimmingCharacters(in: .newlines)
    }
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
