import Foundation
import SwiftDiagnostics
import SwiftParser
import SwiftParserDiagnostics
import SwiftSyntax

// MARK: - AST Modification Rewriters

internal protocol PathAddressable {
    var path: String { get set }
}
