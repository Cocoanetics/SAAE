import Foundation
import SwiftSyntax

/// Rewriter that adjusts indentation throughout a Swift syntax tree.
///
/// This rewriter traverses the syntax tree and applies consistent indentation based on
/// nesting levels. It supports configurable indent size and handles special cases like
/// switch statements where case labels are indented deeper than the switch itself.
///
/// **Note:** String literal content is preserved exactly as-is to maintain semantic meaning.
///
/// ## Features
///
/// - **Configurable indent size**: Set the number of spaces per indentation level
/// - **Nested scope handling**: Automatically detects and indents nested blocks
/// - **Switch/case handling**: Case labels are indented one level deeper than switch
/// - **Preserves structure**: Maintains the logical structure while fixing indentation
///
/// ## Usage
///
/// ```swift
/// let rewriter = IndentationRewriter(indentSize: 4)
/// let reindentedTree = rewriter.visit(syntaxTree)
/// ```
public class IndentationRewriter: SyntaxRewriter {
    
    /// The number of spaces to use for each indentation level.
    private let indentSize: Int
    
    /// Current indentation level (0-based).
    private var currentLevel: Int = 0
    
    /// Creates a new indentation rewriter with the specified indent size.
    ///
    /// - Parameter indentSize: Number of spaces per indentation level (default: 4)
    public init(indentSize: Int = 4) {
        self.indentSize = indentSize
        super.init()
    }
    
    /// Generates the appropriate indentation string for the current level.
    private func indentationString(level: Int) -> String {
        return String(repeating: " ", count: level * indentSize)
    }
    
    /// Applies proper indentation to a node by replacing its leading trivia.
    private func applyIndentation<T: SyntaxProtocol>(_ node: T, level: Int) -> T {
        let existingTrivia = node.leadingTrivia
        var newTrivia: [TriviaPiece] = []
        
        // Keep all non-whitespace trivia (comments, etc.) but track newlines
        var hasNewline = false
        
        for piece in existingTrivia {
            switch piece {
            case .newlines(_), .carriageReturns(_), .carriageReturnLineFeeds(_):
                newTrivia.append(piece)
                hasNewline = true
            case .spaces(_), .tabs(_):
                // Skip existing whitespace, we'll add our own
                continue
            default:
                newTrivia.append(piece)
            }
        }
        
        // ONLY add indentation if there's a newline that precedes this node
        // This prevents adding spaces between tokens on the same line (like "else if")
        if hasNewline && level > 0 {
            newTrivia.append(.spaces(level * indentSize))
        }
        
        return node.with(\.leadingTrivia, Trivia(pieces: newTrivia))
    }
    
    // MARK: - Container Types
    
    public override func visit(_ node: StructDeclSyntax) -> DeclSyntax {
        let indentedNode = applyIndentation(node, level: currentLevel)
        currentLevel += 1
        let result = super.visit(indentedNode)
        currentLevel -= 1
        return result
    }
    
    public override func visit(_ node: ClassDeclSyntax) -> DeclSyntax {
        let indentedNode = applyIndentation(node, level: currentLevel)
        currentLevel += 1
        let result = super.visit(indentedNode)
        currentLevel -= 1
        return result
    }
    
    public override func visit(_ node: EnumDeclSyntax) -> DeclSyntax {
        let indentedNode = applyIndentation(node, level: currentLevel)
        currentLevel += 1
        let result = super.visit(indentedNode)
        currentLevel -= 1
        return result
    }
    
    public override func visit(_ node: ProtocolDeclSyntax) -> DeclSyntax {
        let indentedNode = applyIndentation(node, level: currentLevel)
        currentLevel += 1
        let result = super.visit(indentedNode)
        currentLevel -= 1
        return result
    }
    
    public override func visit(_ node: ActorDeclSyntax) -> DeclSyntax {
        let indentedNode = applyIndentation(node, level: currentLevel)
        currentLevel += 1
        let result = super.visit(indentedNode)
        currentLevel -= 1
        return result
    }
    
    public override func visit(_ node: ExtensionDeclSyntax) -> DeclSyntax {
        let indentedNode = applyIndentation(node, level: currentLevel)
        currentLevel += 1
        let result = super.visit(indentedNode)
        currentLevel -= 1
        return result
    }
    
    // MARK: - Functions and Methods
    
    public override func visit(_ node: FunctionDeclSyntax) -> DeclSyntax {
        let indentedNode = applyIndentation(node, level: currentLevel)
        currentLevel += 1
        let result = super.visit(indentedNode)
        currentLevel -= 1
        return result
    }
    
    public override func visit(_ node: InitializerDeclSyntax) -> DeclSyntax {
        let indentedNode = applyIndentation(node, level: currentLevel)
        currentLevel += 1
        let result = super.visit(indentedNode)
        currentLevel -= 1
        return result
    }
    
    // MARK: - Properties and Variables
    
    public override func visit(_ node: VariableDeclSyntax) -> DeclSyntax {
        let indentedNode = applyIndentation(node, level: currentLevel)
        return super.visit(indentedNode)
    }
    
    // MARK: - Control Flow
    
    public override func visit(_ node: IfExprSyntax) -> ExprSyntax {
        let indentedNode = applyIndentation(node, level: currentLevel)
        currentLevel += 1
        let result = super.visit(indentedNode)
        currentLevel -= 1
        return result
    }
    
    public override func visit(_ node: ForStmtSyntax) -> StmtSyntax {
        let indentedNode = applyIndentation(node, level: currentLevel)
        currentLevel += 1
        let result = super.visit(indentedNode)
        currentLevel -= 1
        return result
    }
    
    public override func visit(_ node: WhileStmtSyntax) -> StmtSyntax {
        let indentedNode = applyIndentation(node, level: currentLevel)
        currentLevel += 1
        let result = super.visit(indentedNode)
        currentLevel -= 1
        return result
    }
    
    public override func visit(_ node: RepeatStmtSyntax) -> StmtSyntax {
        let indentedNode = applyIndentation(node, level: currentLevel)
        currentLevel += 1
        let result = super.visit(indentedNode)
        currentLevel -= 1
        return result
    }
    
    // MARK: - Switch Statements
    
    public override func visit(_ node: SwitchExprSyntax) -> ExprSyntax {
        let indentedNode = applyIndentation(node, level: currentLevel)
        currentLevel += 1
        let result = super.visit(indentedNode)
        currentLevel -= 1
        return result
    }
    
    public override func visit(_ node: SwitchCaseSyntax) -> SwitchCaseSyntax {
        // Case labels get indented at current level (one level deeper than switch)
        let indentedNode = applyIndentation(node, level: currentLevel)
        currentLevel += 1 // Increase level for case body
        let result = super.visit(indentedNode)
        currentLevel -= 1
        return result
    }
    
    // MARK: - Enum Cases
    
    public override func visit(_ node: EnumCaseDeclSyntax) -> DeclSyntax {
        let indentedNode = applyIndentation(node, level: currentLevel)
        return super.visit(indentedNode)
    }
    
    // MARK: - Statements
    
    public override func visit(_ node: ExpressionStmtSyntax) -> StmtSyntax {
        let indentedNode = applyIndentation(node, level: currentLevel)
        return super.visit(indentedNode)
    }
    
    public override func visit(_ node: ReturnStmtSyntax) -> StmtSyntax {
        let indentedNode = applyIndentation(node, level: currentLevel)
        return super.visit(indentedNode)
    }
    
    // MARK: - Type Members
    
    public override func visit(_ node: MemberBlockItemSyntax) -> MemberBlockItemSyntax {
        let indentedNode = applyIndentation(node, level: currentLevel)
        return super.visit(indentedNode)
    }
    
    public override func visit(_ node: CodeBlockItemSyntax) -> CodeBlockItemSyntax {
        let indentedNode = applyIndentation(node, level: currentLevel)
        return super.visit(indentedNode)
    }
    
    // MARK: - Tokens (for closing braces)
    
    public override func visit(_ token: TokenSyntax) -> TokenSyntax {
        // Handle closing braces specifically
        if token.tokenKind == .rightBrace {
            // Closing braces should be at the outer level (currentLevel - 1)
            let braceLevel = max(0, currentLevel - 1)
            return applyIndentation(token, level: braceLevel)
        }
        return super.visit(token)
    }
} 