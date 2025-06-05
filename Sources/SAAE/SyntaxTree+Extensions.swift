import Foundation
import SwiftDiagnostics
import SwiftParser
import SwiftParserDiagnostics
import SwiftSyntax

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

extension SyntaxTree {
/// Adds or replaces the file-level header comment at the very top of the file.
/// - Parameter newHeader: The new header comment (can be multi-line, with or without // or /// prefixes).
/// - Returns: A new SyntaxTree with the updated file header comment.
    public func addOrReplaceFileHeaderComment(newHeader: String) -> SyntaxTree {
        let rewriter = FileLeadingCommentRewriter(newHeader: newHeader)
        let newSourceFile = rewriter.visit(sourceFile)
        return SyntaxTree(newSourceFile, sourceLines: sourceLines, locationConverter: locationConverter)
    }
}

// MARK: - Indentation Support

extension SyntaxTree {

/// Reindents the entire syntax tree with consistent spacing.
///
/// This method applies consistent indentation throughout the syntax tree,
/// with configurable indent size and proper handling of nested scopes.
///
/// - Parameter indentSize: Number of spaces per indentation level (default: 4)
/// - Returns: A new SyntaxTree with consistent indentation applied
/// - Throws: SAAEError if the reindented code cannot be parsed
///
/// ## Features
///
/// - **Configurable spacing**: Set any number of spaces per level
/// - **Nested scope handling**: Automatically indents based on nesting
/// - **Switch/case support**: Case labels indented deeper than switch
/// - **Preserves comments**: Maintains existing documentation and comments
///
/// ## Example
///
/// ```swift
/// let tree = try SyntaxTree(string: sourceCode)
/// let reindentedTree = try tree.reindent(indentSize: 2) // 2 spaces per level
/// let cleanCode = reindentedTree.serializeToCode()
/// ```
    public func reindent(indentSize: Int = 4) throws -> SyntaxTree {
        let rewriter = IndentationRewriter(indentSize: indentSize, locationConverter: locationConverter)
        let reindentedSourceFile = rewriter.visit(sourceFile)

// Serialize the reindented syntax tree back to code and re-parse
        let reindentedCode = reindentedSourceFile.description
        return try SyntaxTree(string: reindentedCode)
    }
}
