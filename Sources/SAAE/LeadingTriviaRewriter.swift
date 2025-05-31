import Foundation
import SwiftDiagnostics
import SwiftParser
import SwiftParserDiagnostics
import SwiftSyntax

// --- Rewriter for leading trivia modification ---
internal class LeadingTriviaRewriter: SyntaxRewriter {
    let targetPath: String
    let newLeadingTriviaText: String?
    var foundTarget = false
    internal var currentTokenPath: [Int] = [] // Path via token indices
    internal var currentTokenIndex: Int = 0

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
