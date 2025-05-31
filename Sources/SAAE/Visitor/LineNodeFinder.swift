import Foundation
import SwiftDiagnostics
import SwiftParser
import SwiftParserDiagnostics
import SwiftSyntax

// --- Line node finder for line number-based addressing ---
internal class LineNodeFinder: SyntaxVisitor {
    let targetLine: Int
    let locationConverter: SourceLocationConverter
    var nodesAtLine: [(node: Syntax, column: Int, length: Int, path: String)] = []
    internal var currentTokenPath: [Int] = []
    internal var currentTokenIndex: Int = 0
    
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
