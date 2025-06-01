import Foundation
import SwiftDiagnostics
import SwiftParser
import SwiftParserDiagnostics
import SwiftSyntax

// MARK: - File Leading Comment Rewriter

/// Rewriter that adds or replaces the leading (file-level) comments at the top of a Swift file.
internal class FileLeadingCommentRewriter: SyntaxRewriter {
    let newHeader: String
    var didReplaceHeader = false

    init(newHeader: String) {
        self.newHeader = newHeader
        super.init(viewMode: .sourceAccurate)
    }

    public override func visit(_ token: TokenSyntax) -> TokenSyntax {
// Only modify the very first token in the file
        guard !didReplaceHeader else { return super.visit(token) }
        didReplaceHeader = true

// Build new leading trivia: header as doc or regular comments, then preserve indentation/newlines
        var newTrivia: [TriviaPiece] = []
        let headerLines = newHeader.split(separator: "\n", omittingEmptySubsequences: false)
        for line in headerLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("///") {
                newTrivia.append(.docLineComment(trimmed))
                newTrivia.append(.newlines(1))
            } else if trimmed.hasPrefix("//") {
                    newTrivia.append(.lineComment(trimmed))
                    newTrivia.append(.newlines(1))
                } else if !trimmed.isEmpty {
                        newTrivia.append(.lineComment("// " + trimmed))
                        newTrivia.append(.newlines(1))
                    } else {
                        newTrivia.append(.newlines(1))
                    }
        }
// Optionally, preserve any existing leading trivia that is not a comment (e.g., spaces, tabs, newlines)
        for piece in token.leadingTrivia.pieces {
            switch piece {
                case .spaces, .tabs, .newlines:
                    newTrivia.append(piece)
                default:
                    continue // skip old comments
            }
        }
        var newToken = token
        newToken.leadingTrivia = Trivia(pieces: newTrivia)
        return super.visit(newToken)
    }
}
