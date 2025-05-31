import Foundation
import SwiftDiagnostics
import SwiftParser
import SwiftParserDiagnostics
import SwiftSyntax

// --- Rewriter for node replacement ---
internal class ReplaceNodeRewriter: SyntaxRewriter {
    let targetPath: String
    let replacementNode: Syntax
    var foundTarget = false
    var invalidContextReason: String?
    internal var currentTokenPath: [Int] = []
    internal var currentTokenIndex: Int = 0

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
