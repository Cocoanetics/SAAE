import Foundation
import SwiftSyntax
import SwiftParser

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
    
    /// Creates a syntax tree by parsing a Swift source file from disk.
    ///
    /// This initializer reads the file content and parses it into a syntax tree. It provides
    /// comprehensive error handling for common file operations.
    ///
    /// - Parameter url: A file URL pointing to a local Swift source file.
    /// - Throws: 
    ///   - ``SAAEError/fileNotFound(_:)`` if the file doesn't exist at the specified path.
    ///   - ``SAAEError/fileReadError(_:_:)`` if the file exists but cannot be read (e.g., due to permissions).
    ///
    /// ## Example
    /// ```swift
    /// let fileURL = URL(fileURLWithPath: "/path/to/MyFile.swift")
    /// let tree = try SyntaxTree(url: fileURL)
    /// ```
    public init(url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw SAAEError.fileNotFound(url)
        }
        
        let codeString: String
        do {
            codeString = try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw SAAEError.fileReadError(url, error)
        }
        
        try self.init(string: codeString)
    }
    
    /// Creates a syntax tree by parsing Swift source code from a string.
    ///
    /// This initializer parses the provided Swift source code directly, without involving file I/O.
    /// It's useful for analyzing dynamically generated code or code provided as string literals.
    ///
    /// - Parameter string: A string containing valid Swift source code to parse.
    /// - Throws: Currently does not throw, but marked as throwing for future compatibility with parsing error handling.
    ///
    /// ## Example
    /// ```swift
    /// let code = """
    /// struct MyStruct {
    ///     let value: Int
    /// }
    /// """
    /// let tree = try SyntaxTree(string: code)
    /// ```
    ///
    /// - Note: SwiftSyntax's parser is generally robust and will attempt to parse even malformed code,
    ///   creating error nodes where necessary rather than failing completely.
    public init(string: String) throws {
    /// Initialize from a Swift source code string
    /// - Parameter string: String containing Swift source code
    /// - Throws: SAAEError if code cannot be parsed
        self.sourceFile = Parser.parse(source: string)
    }
} 
