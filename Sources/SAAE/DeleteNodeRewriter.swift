import Foundation
import SwiftDiagnostics
import SwiftParser
import SwiftParserDiagnostics
import SwiftSyntax

// --- Rewriter for node deletion ---
internal class DeleteNodeRewriter: SyntaxRewriter {
    let targetPath: String
    var foundTarget = false
    var deletedNodeSourceText: String?
    var invalidContextReason: String? // Not currently used as path is token-centric
    internal var currentTokenPath: [Int] = []
    internal var currentTokenIndex: Int = 0

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
