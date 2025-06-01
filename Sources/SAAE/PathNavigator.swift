import Foundation

internal struct PathNavigator {
    internal static func findDeclaration(at path: String, in declarations: [DeclarationOverview]) -> DeclarationOverview? {
        let components = path.split(separator: ".").map(String.init)
        return findDeclarationRecursive(components: components, in: declarations)
    }

    internal static func findDeclarationRecursive(components: [String], in declarations: [DeclarationOverview]) -> DeclarationOverview? {
        guard let firstComponent = components.first else { return nil }

        if let targetIndex = Int(firstComponent), targetIndex > 0 && targetIndex <= declarations.count {
            let target = declarations[targetIndex - 1]

            if components.count == 1 {
                return target
            } else {
                let remainingComponents = Array(components.dropFirst())
                return target.members.flatMap { findDeclarationRecursive(components: remainingComponents, in: $0) }
            }
        }

        return nil
    }
}
