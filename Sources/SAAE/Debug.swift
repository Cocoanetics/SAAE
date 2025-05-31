import Foundation
import SwiftParser
import SwiftSyntax

public func debugPrintTokenLines(_ source: String) {
    let tree = Parser.parse(source: source)
    let converter = SourceLocationConverter(fileName: "source.swift", tree: tree)
    class Printer: SyntaxVisitor {
        let converter: SourceLocationConverter
        init(_ c: SourceLocationConverter) { self.converter = c; super.init(viewMode: .sourceAccurate) }
        override func visit(_ token: TokenSyntax) -> SyntaxVisitorContinueKind {
            let loc = converter.location(for: token.positionAfterSkippingLeadingTrivia)
            print("\(token.text) -> line \(loc.line) col \(loc.column)")
            return .visitChildren
        }
    }
    let printer = Printer(converter)
    printer.walk(tree)
} 