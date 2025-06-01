import Foundation
import SwiftSyntax

/// Syntax rewriter that converts private/fileprivate access modifiers to internal
/// when extracting declarations to separate files
internal class AccessControlRewriter: SyntaxRewriter {

    override func visit(_ node: DeclModifierListSyntax) -> DeclModifierListSyntax {
        let rewritten = node.map { modifier -> DeclModifierSyntax in
        var updatedModifier = modifier
// Determine if we need to update the keyword
        if let detail = modifier.detail, detail.detail.text == "set" {
// Any *(set) becomes internal (detail dropped)
            let newName = TokenSyntax(.keyword(.internal),
										   leadingTrivia: modifier.name.leadingTrivia,
										   trailingTrivia: ensureSpacer(modifier.name.trailingTrivia),
										   presence: .present)
            updatedModifier = modifier
					.with(\.name, newName)
					.with(\.detail, nil)
        } else if modifier.detail == nil,
					  ["private", "fileprivate"].contains(modifier.name.text) {
// Plain private/fileprivate → internal
                let newName = TokenSyntax(.keyword(.internal),
										   leadingTrivia: modifier.name.leadingTrivia,
										   trailingTrivia: ensureSpacer(modifier.name.trailingTrivia),
										   presence: .present)
                updatedModifier = modifier.with(\.name, newName)
            }
        return updatedModifier
    }
        return DeclModifierListSyntax(rewritten)
    }

/// Guarantee at least a single space in trailing trivia (unless newline already present)
    internal func ensureSpacer(_ trivia: Trivia) -> Trivia {
// If trivia already has newline or space, keep as-is
        for piece in trivia {
            if case .newlines(_) = piece { return trivia }
            if case .spaces(let n) = piece, n > 0 { return trivia }
        }
// Otherwise add one space
        return trivia + .spaces(1)
    }
}
