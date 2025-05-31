import Foundation
import SwiftDiagnostics
import SwiftParser
import SwiftParserDiagnostics
import SwiftSyntax

// MARK: - Phase 3: AST Modification API

public enum InsertionPosition {
    case before, after
}
