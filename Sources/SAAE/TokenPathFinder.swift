import Foundation
import SwiftDiagnostics
import SwiftParser
import SwiftParserDiagnostics
import SwiftSyntax

// Helper class to find the path of a specific token
internal class TokenPathFinder: SyntaxVisitor {
    let targetToken: TokenSyntax
    var foundPath: String?
    internal var currentTokenPath: [Int] = []
    internal var currentTokenIndex: Int = 0
    
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
