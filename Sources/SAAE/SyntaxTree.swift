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
        let computedLocation = converter.location(for: byteOffset)
        
        // Apply heuristics to improve error positioning for better UX
        // computedLocation = Self.improveErrorPositioning(
        //     originalLocation: computedLocation,
        //     message: diagnostic.message,
        //     sourceLines: sourceLines
        // )
        
        self.location = computedLocation
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
            // Process all changes for this fix-it together to create a single logical fix-it
            let combinedFixIt = Self.processCombinedFixIt(fixIt, converter: converter, fallbackLocation: self.location)
            if let fix = combinedFixIt {
                fixIts.append(fix)
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
    
    /// Processes a combined fix-it from multiple changes
    private static func processCombinedFixIt(_ fixIt: FixIt, converter: SourceLocationConverter, fallbackLocation: SourceLocation) -> SyntaxFixIt? {
        var insertions: [String] = []
        var removals: [String] = []
        var replacements: [(String, String)] = []
        var primaryLocation: SourceLocation = fallbackLocation
        var hasValidChanges = false
        
        // Process all changes and categorize them
        for change in fixIt.changes {
            switch change {
            case .replace(let oldNode, let newNode):
                let location = converter.location(for: oldNode.position)
                let originalText = oldNode.description
                let replacementText = newNode.description
                
                // Use the first valid location as primary
                if !hasValidChanges {
                    primaryLocation = location
                    hasValidChanges = true
                }
                
                if originalText.isEmpty && !replacementText.isEmpty {
                    // This is an insertion
                    insertions.append(replacementText)
                } else if !originalText.isEmpty && replacementText.isEmpty {
                    // This is a removal
                    removals.append(originalText)
                } else if !originalText.isEmpty && !replacementText.isEmpty {
                    // This is a replacement
                    replacements.append((originalText, replacementText))
                }
                
            case .replaceLeadingTrivia(let token, let newTrivia):
                let location = converter.location(for: token.position)
                let originalText = token.leadingTrivia.description
                let replacementText = newTrivia.description
                
                // Skip meaningless trivia changes
                if originalText.isEmpty && replacementText.isEmpty {
                    continue
                }
                
                if !hasValidChanges {
                    primaryLocation = location
                    hasValidChanges = true
                }
                
                if originalText.isEmpty && !replacementText.isEmpty {
                    insertions.append(replacementText)
                } else if !originalText.isEmpty && replacementText.isEmpty {
                    removals.append(originalText)
                } else if !originalText.isEmpty && !replacementText.isEmpty {
                    replacements.append((originalText, replacementText))
                }
                
            case .replaceTrailingTrivia(let token, let newTrivia):
                let location = converter.location(for: token.endPositionBeforeTrailingTrivia)
                let originalText = token.trailingTrivia.description
                let replacementText = newTrivia.description
                
                // Skip meaningless trivia changes
                if originalText.isEmpty && replacementText.isEmpty {
                    continue
                }
                
                if !hasValidChanges {
                    primaryLocation = location
                    hasValidChanges = true
                }
                
                if originalText.isEmpty && !replacementText.isEmpty {
                    insertions.append(replacementText)
                } else if !originalText.isEmpty && replacementText.isEmpty {
                    removals.append(originalText)
                } else if !originalText.isEmpty && !replacementText.isEmpty {
                    replacements.append((originalText, replacementText))
                }
                
            @unknown default:
                // For unknown change types, create a generic fix-it
                if !hasValidChanges {
                    hasValidChanges = true
                }
            }
        }
        
        // If no valid changes were found, return nil
        guard hasValidChanges else { return nil }
        
        // Generate a combined message based on the changes
        let message = generateCombinedFixItMessage(
            insertions: insertions,
            removals: removals,
            replacements: replacements
        )
        
        // For the combined fix-it, we'll use the concatenated insertions as replacementText
        // and empty string as originalText (since it's a composite operation)
        let combinedReplacementText = insertions.joined(separator: "")
        
        return SyntaxFixIt(
            message: message,
            originalText: "",
            replacementText: combinedReplacementText,
            range: primaryLocation
        )
    }
    
    /// Generates a human-readable message for combined fix-it operations
    private static func generateCombinedFixItMessage(
        insertions: [String],
        removals: [String],
        replacements: [(String, String)]
    ) -> String {
        var messageParts: [String] = []
        
        // Handle insertions
        if !insertions.isEmpty {
            let escapedInsertions = insertions.map { escapeForDisplay($0) }
            if insertions.count == 1 {
                messageParts.append("insert `\(escapedInsertions[0])`")
            } else {
                let combined = escapedInsertions.joined(separator: "")
                messageParts.append("insert `\(combined)`")
            }
        }
        
        // Handle removals
        if !removals.isEmpty {
            let escapedRemovals = removals.map { escapeForDisplay($0) }
            if removals.count == 1 {
                messageParts.append("remove `\(escapedRemovals[0])`")
            } else {
                messageParts.append("remove `\(escapedRemovals.joined(separator: ", "))`")
            }
        }
        
        // Handle replacements
        for (original, replacement) in replacements {
            let escapedOrig = escapeForDisplay(original)
            let escapedRepl = escapeForDisplay(replacement)
            messageParts.append("replace `\(escapedOrig)` with `\(escapedRepl)`")
        }
        
        // Combine all parts
        if messageParts.isEmpty {
            return "fix syntax error"
        } else if messageParts.count == 1 {
            return messageParts[0]
        } else {
            return messageParts.joined(separator: " and ")
        }
    }
    
    /// Escapes special characters in text for readable display in fix-it messages
    private static func escapeForDisplay(_ text: String) -> String {
        var result = text
        
        // Escape all types of whitespace and special characters
        // Order matters: escape compound sequences first
        result = result.replacingOccurrences(of: "\\", with: "\\\\") // Escape backslashes first
        result = result.replacingOccurrences(of: "\r\n", with: "\\r\\n") // Handle Windows line endings first
        result = result.replacingOccurrences(of: "\n", with: "\\n")
        result = result.replacingOccurrences(of: "\r", with: "\\r") 
        result = result.replacingOccurrences(of: "\t", with: "\\t")
        result = result.replacingOccurrences(of: "\u{000B}", with: "\\v") // Vertical tab
        result = result.replacingOccurrences(of: "\u{000C}", with: "\\f") // Form feed
        
        return result
    }
    
    /// Applies heuristics to improve error positioning for better UX
    private static func improveErrorPositioning(originalLocation: SourceLocation, message: String, sourceLines: [String]) -> SourceLocation {
        // General heuristic: "unexpected code 'XXXX' ..." errors are often mispositioned by SwiftSyntax
        // They should point to where the quoted code actually appears, not where SwiftSyntax thinks it should be reported
        if message.contains("unexpected code") {
            return adjustUnexpectedCodeError(originalLocation: originalLocation, sourceLines: sourceLines, message: message)
        }
        
        // Add more heuristics here as needed in the future
        
        return originalLocation
    }
    
    /// Adjusts error position for "unexpected code 'XXXX' ..." errors that are misplaced by SwiftSyntax
    private static func adjustUnexpectedCodeError(originalLocation: SourceLocation, sourceLines: [String], message: String) -> SourceLocation {
        let currentLineIndex = originalLocation.line - 1 // Convert to 0-based
        
        // Extract the problematic code from the error message
        // Pattern: "unexpected code 'XXXXX' ..."
        var problematicCode: String? = nil
        
        if let startQuote = message.range(of: "'"),
           let endQuote = message.range(of: "'", range: startQuote.upperBound..<message.endIndex) {
            problematicCode = String(message[startQuote.upperBound..<endQuote.lowerBound])
        }
        
        // If we can't extract specific code, return original location
        guard let code = problematicCode else {
            return originalLocation
        }
        
        // First check the current line where the error is reported
        if currentLineIndex < sourceLines.count {
            let currentLine = sourceLines[currentLineIndex]
            
            if currentLine.contains(code) {
                // Find the position of the problematic code in the line
                guard let codeRange = currentLine.range(of: code) else {
                    // Fallback to start of non-whitespace content
                    let column = currentLine.firstIndex(where: { !$0.isWhitespace }).map { 
                        currentLine.distance(from: currentLine.startIndex, to: $0) + 1 
                    } ?? 1
                    
                    return SourceLocation(
                        line: currentLineIndex + 1, // Convert back to 1-based
                        column: column,
                        offset: originalLocation.offset,
                        file: originalLocation.file
                    )
                }
                
                let column = currentLine.distance(from: currentLine.startIndex, to: codeRange.lowerBound) + 1
                
                return SourceLocation(
                    line: currentLineIndex + 1, // Convert back to 1-based
                    column: column,
                    offset: originalLocation.offset,
                    file: originalLocation.file
                )
            }
        }
        
        // Then search backwards if not found on current line
        // Look backwards from current position to find the line containing the problematic code
        var searchLineIndex = currentLineIndex - 1
        let maxSearchLines = 5 // Search a reasonable distance back
        
        while searchLineIndex >= 0 && (currentLineIndex - searchLineIndex) <= maxSearchLines {
            guard searchLineIndex < sourceLines.count else { break }
            
            let originalLine = sourceLines[searchLineIndex]
            
            // Check if this line contains the problematic code mentioned in the error
            if originalLine.contains(code) {
                // Find the position of the problematic code in the line
                guard let codeRange = originalLine.range(of: code) else {
                    // Fallback to start of non-whitespace content
                    let column = originalLine.firstIndex(where: { !$0.isWhitespace }).map { 
                        originalLine.distance(from: originalLine.startIndex, to: $0) + 1 
                    } ?? 1
                    
                    return SourceLocation(
                        line: searchLineIndex + 1, // Convert back to 1-based
                        column: column,
                        offset: originalLocation.offset,
                        file: originalLocation.file
                    )
                }
                
                let column = originalLine.distance(from: originalLine.startIndex, to: codeRange.lowerBound) + 1
                
                return SourceLocation(
                    line: searchLineIndex + 1, // Convert back to 1-based
                    column: column,
                    offset: originalLocation.offset,
                    file: originalLocation.file
                )
            }
            
            searchLineIndex -= 1
        }
        
        // If no problematic code found, return original location
        return originalLocation
    }
} 

// MARK: - Phase 3: AST Modification API

public enum InsertionPosition {
    case before, after
}

extension SyntaxTree {
    /// Serializes the syntax tree back to Swift source code.
    public func serializeToCode() -> String {
        return sourceFile.description
    }

    /// Modifies the leading trivia (documentation) for the node at the given path.
    public func modifyLeadingTrivia(forNodeAtPath nodePath: String, newLeadingTriviaText: String?) throws -> SyntaxTree {
        let rewriter = LeadingTriviaRewriter(targetPath: nodePath, newLeadingTriviaText: newLeadingTriviaText)
        let newSourceFile = rewriter.visit(sourceFile)
        if !rewriter.foundTarget {
            throw NodeOperationError.nodeNotFound(path: nodePath)
        }
        return SyntaxTree(newSourceFile, sourceLines: sourceLines, locationConverter: locationConverter)
    }

    /// Replaces the node at the given path with a new node.
    public func replaceNode(atPath nodePath: String, withNewNode newNode: Syntax) throws -> SyntaxTree {
        let rewriter = ReplaceNodeRewriter(targetPath: nodePath, replacement: newNode)
        let newSourceFile = rewriter.visit(sourceFile)
        if !rewriter.foundTarget {
            throw NodeOperationError.nodeNotFound(path: nodePath)
        }
        if rewriter.invalidContextReason != nil {
            throw NodeOperationError.invalidReplacementContext(reason: rewriter.invalidContextReason!)
        }
        return SyntaxTree(newSourceFile, sourceLines: sourceLines, locationConverter: locationConverter)
    }

    /// Deletes the node at the given path. Returns the deleted node's source text and the new tree.
    public func deleteNode(atPath nodePath: String) throws -> (deletedNodeSourceText: String?, newTree: SyntaxTree) {
        let rewriter = DeleteNodeRewriter(targetPath: nodePath)
        let newSourceFile = rewriter.visit(sourceFile)
        if !rewriter.foundTarget {
            throw NodeOperationError.nodeNotFound(path: nodePath)
        }
        if rewriter.invalidContextReason != nil {
            throw NodeOperationError.invalidReplacementContext(reason: rewriter.invalidContextReason!)
        }
        return (rewriter.deletedNodeSourceText, SyntaxTree(newSourceFile, sourceLines: sourceLines, locationConverter: locationConverter))
    }

    /// Inserts new nodes before or after the anchor node at the given path.
    public func insertNodes(_ newNodes: [Syntax], relativeToNodeAtPath anchorNodePath: String, position: InsertionPosition) throws -> SyntaxTree {
        let rewriter = InsertNodesRewriter(anchorPath: anchorNodePath, newNodes: newNodes, position: position)
        let newSourceFile = rewriter.visit(sourceFile)
        if !rewriter.foundAnchor {
            throw NodeOperationError.nodeNotFound(path: anchorNodePath)
        }
        if rewriter.invalidContextReason != nil {
            throw NodeOperationError.invalidInsertionPoint(reason: rewriter.invalidContextReason!)
        }
        return SyntaxTree(newSourceFile, sourceLines: sourceLines, locationConverter: locationConverter)
    }

    // Internal initializer for new trees from rewritten SourceFileSyntax
    internal init(_ sourceFile: SourceFileSyntax, sourceLines: [String], locationConverter: SourceLocationConverter) {
        self.sourceFile = sourceFile
        self.sourceLines = sourceLines
        self.locationConverter = locationConverter
    }

    // MARK: - Line Number-Based AST Modification API
    
    /// Node selection strategy when multiple nodes exist on the same line
    public enum LineNodeSelection {
        case first          // Select the first node on the line
        case last           // Select the last node on the line  
        case largest        // Select the node with the most content
        case smallest       // Select the node with the least content
        case atColumn(Int)  // Select the node closest to the specified column
    }
    
    /// Information about nodes found at a specific line
    public struct LineNodeInfo {
        public let line: Int
        public let nodes: [(node: Syntax, column: Int, length: Int, path: String)]
        public let selectedNode: (node: Syntax, column: Int, length: Int, path: String)?
        public let selection: LineNodeSelection
    }
    
    /// Finds nodes at a specific line number with selection strategy
    public func findNodesAtLine(_ lineNumber: Int, selection: LineNodeSelection = .first) -> LineNodeInfo {
        let finder = LineNodeFinder(targetLine: lineNumber, locationConverter: locationConverter)
        finder.walk(sourceFile)
        
        let selectedNode: (node: Syntax, column: Int, length: Int, path: String)?
        
        switch selection {
        case .first:
            selectedNode = finder.nodesAtLine.first
        case .last:
            selectedNode = finder.nodesAtLine.last
        case .largest:
            selectedNode = finder.nodesAtLine.max { $0.length < $1.length }
        case .smallest:
            selectedNode = finder.nodesAtLine.min { $0.length < $1.length }
        case .atColumn(let targetColumn):
            selectedNode = finder.nodesAtLine.min { 
                abs($0.column - targetColumn) < abs($1.column - targetColumn)
            }
        }
        
        return LineNodeInfo(
            line: lineNumber,
            nodes: finder.nodesAtLine,
            selectedNode: selectedNode,
            selection: selection
        )
    }
    
    /// Modifies the leading trivia for the node at the given line number.
    public func modifyLeadingTrivia(atLine lineNumber: Int, newLeadingTriviaText: String?, selection: LineNodeSelection = .first) throws -> SyntaxTree {
        let nodeInfo = findNodesAtLine(lineNumber, selection: selection)
        guard let selectedNode = nodeInfo.selectedNode else {
            throw NodeOperationError.nodeNotFound(path: "line \(lineNumber)")
        }
        
        // Use the path from the selected node to perform the modification
        return try modifyLeadingTrivia(forNodeAtPath: selectedNode.path, newLeadingTriviaText: newLeadingTriviaText)
    }
    
    /// Replaces the node at the given line number with a new node.
    public func replaceNode(atLine lineNumber: Int, withNewNode newNode: Syntax, selection: LineNodeSelection = .first) throws -> SyntaxTree {
        let nodeInfo = findNodesAtLine(lineNumber, selection: selection)
        guard let selectedNode = nodeInfo.selectedNode else {
            throw NodeOperationError.nodeNotFound(path: "line \(lineNumber)")
        }
        
        return try replaceNode(atPath: selectedNode.path, withNewNode: newNode)
    }
    
    /// Deletes the node at the given line number.
    public func deleteNode(atLine lineNumber: Int, selection: LineNodeSelection = .first) throws -> (deletedNodeSourceText: String?, newTree: SyntaxTree) {
        let nodeInfo = findNodesAtLine(lineNumber, selection: selection)
        guard let selectedNode = nodeInfo.selectedNode else {
            throw NodeOperationError.nodeNotFound(path: "line \(lineNumber)")
        }
        
        return try deleteNode(atPath: selectedNode.path)
    }
    
    /// Inserts new nodes before or after the anchor node at the given line number.
    public func insertNodes(_ newNodes: [Syntax], relativeToLine lineNumber: Int, position: InsertionPosition, selection: LineNodeSelection = .first) throws -> SyntaxTree {
        let nodeInfo = findNodesAtLine(lineNumber, selection: selection)
        guard let selectedNode = nodeInfo.selectedNode else {
            throw NodeOperationError.nodeNotFound(path: "line \(lineNumber)")
        }
        
        return try insertNodes(newNodes, relativeToNodeAtPath: selectedNode.path, position: position)
    }
}

// MARK: - AST Modification Rewriters

fileprivate protocol PathAddressable {
    var path: String { get set }
}

fileprivate class PathTrackingVisitor: SyntaxVisitor {
    let targetPath: String
    var currentPath: [Int] = []
    var foundNode: Syntax?
    var foundParent: Syntax?
    var foundIndexInParent: Int?
    var foundTarget: Bool = false
    var currentIndex: Int = 0 // Tracks all nodes visited by this specific visitor if used generically

    init(targetPath: String) {
        self.targetPath = targetPath
        super.init(viewMode: .sourceAccurate)
    }

    // Note: Specific visit methods would be needed here if PathTrackingVisitor
    // itself was meant to find a specific *type* of node by path.
    // For the rewriters below, path tracking is re-implemented token-centrically.
}

// --- Rewriter for leading trivia modification ---
fileprivate class LeadingTriviaRewriter: SyntaxRewriter {
    let targetPath: String
    let newLeadingTriviaText: String?
    var foundTarget = false
    private var currentTokenPath: [Int] = [] // Path via token indices
    private var currentTokenIndex: Int = 0

    init(targetPath: String, newLeadingTriviaText: String?) {
        self.targetPath = targetPath
        self.newLeadingTriviaText = newLeadingTriviaText
        super.init(viewMode: .sourceAccurate)
    }

    public override func visit(_ token: TokenSyntax) -> TokenSyntax { // Correct signature
        currentTokenIndex += 1
        currentTokenPath.append(currentTokenIndex)
        let pathString = currentTokenPath.map(String.init).joined(separator: ".")

        var resultToken = token
        if pathString == targetPath {
            foundTarget = true
            var mutableToken = token // Make a mutable copy to modify trivia
            let newPieces: [TriviaPiece]
            if let text = newLeadingTriviaText {
                let pieces = token.leadingTrivia.pieces
                var indent: [TriviaPiece] = []
                var rest: [TriviaPiece] = []
                var foundNonIndent = false
                for piece in pieces {
                    switch piece {
                    case .spaces, .tabs:
                        if !foundNonIndent {
                            indent.append(piece)
                        } else {
                            rest.append(piece)
                        }
                    default:
                        foundNonIndent = true
                        rest.append(piece)
                    }
                }
                var combined: [TriviaPiece] = []
                combined.append(contentsOf: indent)
                combined.append(.docLineComment(text))
                combined.append(.newlines(1))
                combined.append(contentsOf: rest)
                newPieces = combined
            } else {
                newPieces = token.leadingTrivia.pieces
            }
            mutableToken.leadingTrivia = Trivia(pieces: newPieces)
            resultToken = mutableToken
        }
        _ = currentTokenPath.popLast()
        return super.visit(resultToken) // Call super with the (potentially modified) token
    }
}

// --- Rewriter for node replacement ---
fileprivate class ReplaceNodeRewriter: SyntaxRewriter {
    let targetPath: String
    let replacementNode: Syntax
    var foundTarget = false
    var invalidContextReason: String?
    private var currentTokenPath: [Int] = []
    private var currentTokenIndex: Int = 0

    init(targetPath: String, replacement: Syntax) {
        self.targetPath = targetPath
        self.replacementNode = replacement
        super.init(viewMode: .sourceAccurate)
    }

    public override func visit(_ token: TokenSyntax) -> TokenSyntax {
        currentTokenIndex += 1
        currentTokenPath.append(currentTokenIndex)
        let pathString = currentTokenPath.map(String.init).joined(separator: ".")

        var resultToken = token
        if pathString == targetPath {
            foundTarget = true
            if let newSpecificToken = replacementNode.as(TokenSyntax.self) {
                // Preserve the original token's trivia when replacing
                var modifiedToken = newSpecificToken
                modifiedToken.leadingTrivia = token.leadingTrivia
                modifiedToken.trailingTrivia = token.trailingTrivia
                resultToken = modifiedToken
            } else {
                invalidContextReason = "Path \(targetPath) points to a Token, but replacement node is not a Token. Token-level replacement currently requires a Token."
                // Return original token; main API will check invalidContextReason
            }
        }
        _ = currentTokenPath.popLast()
        return super.visit(resultToken)
    }
}

// --- Rewriter for node deletion ---
fileprivate class DeleteNodeRewriter: SyntaxRewriter {
    let targetPath: String
    var foundTarget = false
    var deletedNodeSourceText: String?
    var invalidContextReason: String? // Not currently used as path is token-centric
    private var currentTokenPath: [Int] = []
    private var currentTokenIndex: Int = 0

    init(targetPath: String) {
        self.targetPath = targetPath
        super.init(viewMode: .sourceAccurate)
    }

    public override func visit(_ token: TokenSyntax) -> TokenSyntax {
        currentTokenIndex += 1
        currentTokenPath.append(currentTokenIndex)
        let pathString = currentTokenPath.map(String.init).joined(separator: ".")

        var resultToken = token
        if pathString == targetPath {
            foundTarget = true
            deletedNodeSourceText = token.description
            resultToken = TokenSyntax.identifier("") // Replace with an empty identifier token
        }
        _ = currentTokenPath.popLast()
        return super.visit(resultToken)
    }
}

// --- Rewriter for node insertion ---
fileprivate class InsertNodesRewriter: SyntaxRewriter {
    let anchorPath: String
    let newNodes: [Syntax]
    let position: InsertionPosition
    var foundAnchor = false
    var invalidContextReason: String?

    init(anchorPath: String, newNodes: [Syntax], position: InsertionPosition) {
        self.anchorPath = anchorPath
        self.newNodes = newNodes
        self.position = position
        super.init(viewMode: .sourceAccurate)
        self.invalidContextReason = "Node insertion is not implemented."
    }
    // This rewriter remains a no-op for now as insertion is complex.
}

// --- Line node finder for line number-based addressing ---
fileprivate class LineNodeFinder: SyntaxVisitor {
    let targetLine: Int
    let locationConverter: SourceLocationConverter
    var nodesAtLine: [(node: Syntax, column: Int, length: Int, path: String)] = []
    private var currentTokenPath: [Int] = []
    private var currentTokenIndex: Int = 0
    
    init(targetLine: Int, locationConverter: SourceLocationConverter) {
        self.targetLine = targetLine
        self.locationConverter = locationConverter
        super.init(viewMode: .sourceAccurate)
    }
    
    public override func visit(_ token: TokenSyntax) -> SyntaxVisitorContinueKind {
        currentTokenIndex += 1
        currentTokenPath.append(currentTokenIndex)
        
        // Get the location of this token's content, after its leading trivia
        let contentPosition = token.positionAfterSkippingLeadingTrivia // Back to positionAfterSkippingLeadingTrivia
        let location = locationConverter.location(for: contentPosition)
        
        // If this token starts on our target line, record it
        if location.line == targetLine {
            // Temporarily always add if in range, to see what lines ARE found
            let length = token.description.count
            let pathString = currentTokenPath.map(String.init).joined(separator: ".")
            
            nodesAtLine.append((
                node: Syntax(token),
                column: location.column,
                length: length,
                path: pathString
            ))
        }
        
        _ = currentTokenPath.popLast()
        return .visitChildren
    }
}

// Helper class to find the path of a specific token
fileprivate class TokenPathFinder: SyntaxVisitor {
    let targetToken: TokenSyntax
    var foundPath: String?
    private var currentTokenPath: [Int] = []
    private var currentTokenIndex: Int = 0
    
    init(targetToken: TokenSyntax) {
        self.targetToken = targetToken
        super.init(viewMode: .sourceAccurate)
    }
    
    public override func visit(_ token: TokenSyntax) -> SyntaxVisitorContinueKind {
        currentTokenIndex += 1
        currentTokenPath.append(currentTokenIndex)
        
        // Check if this is our target token by comparing positions
        if token.position == targetToken.position {
            foundPath = currentTokenPath.map(String.init).joined(separator: ".")
            return .skipChildren
        }
        
        _ = currentTokenPath.popLast()
        return .visitChildren
    }
} 
