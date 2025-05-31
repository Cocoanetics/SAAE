import Foundation
import SwiftDiagnostics
import SwiftParser
import SwiftParserDiagnostics
import SwiftSyntax

internal protocol PathAddressable {
    var path: String { get set }
}
