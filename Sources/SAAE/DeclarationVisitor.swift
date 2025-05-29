import Foundation
import SwiftSyntax

/// Visitor class that traverses the AST and extracts declaration information
internal class DeclarationVisitor: SyntaxVisitor {
    
    private let minVisibility: VisibilityLevel
    private(set) var declarations: [DeclarationOverview] = []
    
    // Context tracking for path generation and nesting
    private var pathComponents: [Int] = []
    private var currentIndex: Int = 0
    private var parentNames: [String] = []
    
    init(minVisibility: VisibilityLevel) {
        self.minVisibility = minVisibility
        super.init(viewMode: .sourceAccurate)
    }
    
    override func visit(_ node: SourceFileSyntax) -> SyntaxVisitorContinueKind {
        // Reset state for new file
        pathComponents = []
        currentIndex = 0
        parentNames = []
        declarations = []
        
        return .visitChildren
    }
    
    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        processDeclaration(node, type: "struct")
        return .skipChildren
    }
    
    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        processDeclaration(node, type: "class")
        return .skipChildren
    }
    
    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        processDeclaration(node, type: "enum")
        return .skipChildren
    }
    
    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        processDeclaration(node, type: "protocol")
        return .skipChildren
    }
    
    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        processExtension(node)
        return .skipChildren
    }
    
    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        return processFunction(node)
    }
    
    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        return processVariable(node)
    }
    
    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        return processInitializer(node)
    }
    
    override func visit(_ node: SubscriptDeclSyntax) -> SyntaxVisitorContinueKind {
        return processSubscript(node)
    }
    
    override func visit(_ node: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind {
        return processTypeAlias(node)
    }
    
    // MARK: - Processing Methods
    
    private func processDeclaration<T: DeclSyntaxProtocol & NamedDeclSyntax>(_ node: T, type: String) {
        let visibility = extractVisibility(from: node)
        guard visibility >= minVisibility else { return }
        
        currentIndex += 1
        let currentPath = generatePath()
        
        let name = node.name.text
        let fullName = generateFullName(name)
        let documentation = extractDocumentation(from: node)
        
        // Process members if this is a container type
        let (members, childPaths) = processMembers(of: node, basePath: currentPath, parentName: fullName)
        
        let overview = DeclarationOverview(
            path: currentPath,
            type: type,
            name: name,
            fullName: fullName,
            signature: nil, // Container types don't have signatures in this implementation
            visibility: visibility.stringValue,
            documentation: documentation,
            members: members.isEmpty ? nil : members,
            childPaths: childPaths.isEmpty ? nil : childPaths
        )
        
        declarations.append(overview)
    }
    
    private func processExtension(_ node: ExtensionDeclSyntax) {
        let visibility = extractVisibility(from: node)
        guard visibility >= minVisibility else { return }
        
        currentIndex += 1
        let currentPath = generatePath()
        
        let extendedType = node.extendedType.description.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = extendedType
        let fullName = generateFullName(name)
        let documentation = extractDocumentation(from: node)
        
        // Process members of the extension
        let (members, childPaths) = processMembers(of: node, basePath: currentPath, parentName: fullName)
        
        let overview = DeclarationOverview(
            path: currentPath,
            type: "extension",
            name: name,
            fullName: fullName,
            signature: nil,
            visibility: visibility.stringValue,
            documentation: documentation,
            members: members.isEmpty ? nil : members,
            childPaths: childPaths.isEmpty ? nil : childPaths
        )
        
        declarations.append(overview)
    }
    
    private func processFunction(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        let visibility = extractVisibility(from: node)
        guard visibility >= minVisibility else { return .skipChildren }
        
        currentIndex += 1
        let currentPath = generatePath()
        
        let name = node.name.text
        let fullName = generateFullName(name)
        let signature = generateFunctionSignature(node)
        let documentation = extractDocumentation(from: node)
        
        let overview = DeclarationOverview(
            path: currentPath,
            type: "func",
            name: name,
            fullName: fullName,
            signature: signature,
            visibility: visibility.stringValue,
            documentation: documentation
        )
        
        declarations.append(overview)
        return .skipChildren
    }
    
    private func processVariable(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        let visibility = extractVisibility(from: node)
        guard visibility >= minVisibility else { return .skipChildren }
        
        // Variables can have multiple bindings
        for binding in node.bindings {
            if let pattern = binding.pattern.as(IdentifierPatternSyntax.self) {
                currentIndex += 1
                let currentPath = generatePath()
                
                let name = pattern.identifier.text
                let fullName = generateFullName(name)
                let signature = generateVariableSignature(binding, isLet: node.bindingSpecifier.text == "let")
                let documentation = extractDocumentation(from: node)
                
                let overview = DeclarationOverview(
                    path: currentPath,
                    type: node.bindingSpecifier.text, // "var" or "let"
                    name: name,
                    fullName: fullName,
                    signature: signature,
                    visibility: visibility.stringValue,
                    documentation: documentation
                )
                
                declarations.append(overview)
            }
        }
        return .skipChildren
    }
    
    private func processInitializer(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        let visibility = extractVisibility(from: node)
        guard visibility >= minVisibility else { return .skipChildren }
        
        currentIndex += 1
        let currentPath = generatePath()
        
        let name = "init"
        let fullName = generateFullName(name)
        let signature = generateInitializerSignature(node)
        let documentation = extractDocumentation(from: node)
        
        let overview = DeclarationOverview(
            path: currentPath,
            type: "initializer",
            name: name,
            fullName: fullName,
            signature: signature,
            visibility: visibility.stringValue,
            documentation: documentation
        )
        
        declarations.append(overview)
        return .skipChildren
    }
    
    private func processSubscript(_ node: SubscriptDeclSyntax) -> SyntaxVisitorContinueKind {
        let visibility = extractVisibility(from: node)
        guard visibility >= minVisibility else { return .skipChildren }
        
        currentIndex += 1
        let currentPath = generatePath()
        
        let name = "subscript"
        let fullName = generateFullName(name)
        let signature = generateSubscriptSignature(node)
        let documentation = extractDocumentation(from: node)
        
        let overview = DeclarationOverview(
            path: currentPath,
            type: "subscript",
            name: name,
            fullName: fullName,
            signature: signature,
            visibility: visibility.stringValue,
            documentation: documentation
        )
        
        declarations.append(overview)
        return .skipChildren
    }
    
    private func processTypeAlias(_ node: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind {
        let visibility = extractVisibility(from: node)
        guard visibility >= minVisibility else { return .skipChildren }
        
        currentIndex += 1
        let currentPath = generatePath()
        
        let name = node.name.text
        let fullName = generateFullName(name)
        let signature = generateTypeAliasSignature(node)
        let documentation = extractDocumentation(from: node)
        
        let overview = DeclarationOverview(
            path: currentPath,
            type: "typealias",
            name: name,
            fullName: fullName,
            signature: signature,
            visibility: visibility.stringValue,
            documentation: documentation
        )
        
        declarations.append(overview)
        return .skipChildren
    }
    
    // MARK: - Helper Methods
    
    private func processMembers<T: SyntaxProtocol>(of node: T, basePath: String, parentName: String) -> ([DeclarationOverview], [String]) {
        // Create a new visitor for members
        let memberVisitor = DeclarationVisitor(minVisibility: minVisibility)
        memberVisitor.pathComponents = pathComponents + [currentIndex]
        memberVisitor.currentIndex = 0
        memberVisitor.parentNames = parentNames + [parentName.components(separatedBy: ".").last ?? parentName]
        
        // Find the member block
        if let memberBlock = findMemberBlock(in: node) {
            memberVisitor.walk(memberBlock)
        }
        
        let childPaths = memberVisitor.declarations.map { $0.path }
        return (memberVisitor.declarations, childPaths)
    }
    
    private func findMemberBlock<T: SyntaxProtocol>(in node: T) -> SyntaxProtocol? {
        if let structDecl = node.as(StructDeclSyntax.self) {
            return structDecl.memberBlock
        } else if let classDecl = node.as(ClassDeclSyntax.self) {
            return classDecl.memberBlock
        } else if let enumDecl = node.as(EnumDeclSyntax.self) {
            return enumDecl.memberBlock
        } else if let protocolDecl = node.as(ProtocolDeclSyntax.self) {
            return protocolDecl.memberBlock
        } else if let extensionDecl = node.as(ExtensionDeclSyntax.self) {
            return extensionDecl.memberBlock
        }
        return nil
    }
    
    private func generatePath() -> String {
        let components = pathComponents + [currentIndex]
        return components.map(String.init).joined(separator: ".")
    }
    
    private func generateFullName(_ name: String) -> String {
        let allNames = parentNames + [name]
        return allNames.joined(separator: ".")
    }
    
    private func extractVisibility<T: SyntaxProtocol>(from node: T) -> VisibilityLevel {
        // Try to extract modifiers from different declaration types
        var modifiers: DeclModifierListSyntax?
        
        if let structDecl = node.as(StructDeclSyntax.self) {
            modifiers = structDecl.modifiers
        } else if let classDecl = node.as(ClassDeclSyntax.self) {
            modifiers = classDecl.modifiers
        } else if let enumDecl = node.as(EnumDeclSyntax.self) {
            modifiers = enumDecl.modifiers
        } else if let protocolDecl = node.as(ProtocolDeclSyntax.self) {
            modifiers = protocolDecl.modifiers
        } else if let extensionDecl = node.as(ExtensionDeclSyntax.self) {
            modifiers = extensionDecl.modifiers
        } else if let functionDecl = node.as(FunctionDeclSyntax.self) {
            modifiers = functionDecl.modifiers
        } else if let variableDecl = node.as(VariableDeclSyntax.self) {
            modifiers = variableDecl.modifiers
        } else if let initDecl = node.as(InitializerDeclSyntax.self) {
            modifiers = initDecl.modifiers
        } else if let subscriptDecl = node.as(SubscriptDeclSyntax.self) {
            modifiers = subscriptDecl.modifiers
        } else if let typeAliasDecl = node.as(TypeAliasDeclSyntax.self) {
            modifiers = typeAliasDecl.modifiers
        }
        
        guard let modifiers = modifiers else {
            return .internal // Default visibility in Swift
        }
        
        for modifier in modifiers {
            switch modifier.name.text {
            case "private": return .private
            case "fileprivate": return .fileprivate
            case "internal": return .internal
            case "package": return .package
            case "public": return .public
            case "open": return .open
            default: continue
            }
        }
        return .internal // Default visibility in Swift
    }
    
    private func extractDocumentation<T: SyntaxProtocol>(from node: T) -> Documentation? {
        let leadingTrivia = node.leadingTrivia
        var docText = ""
        
        for piece in leadingTrivia {
            switch piece {
            case .docLineComment(let text):
                if !docText.isEmpty { docText += "\n" }
                docText += text
            case .docBlockComment(let text):
                if !docText.isEmpty { docText += "\n" }
                docText += text
            default:
                continue
            }
        }
        
        guard !docText.isEmpty else { return nil }
        return Documentation(from: docText)
    }
    
    // MARK: - Signature Generation
    
    private func generateFunctionSignature(_ node: FunctionDeclSyntax) -> String {
        var signature = "func \(node.name.text)"
        
        // Generic parameters
        if let genericParams = node.genericParameterClause {
            signature += genericParams.description.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Parameters
        signature += node.signature.parameterClause.description.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Async/throws
        if let effectSpecifiers = node.signature.effectSpecifiers {
            if effectSpecifiers.asyncSpecifier != nil {
                signature += " async"
            }
            if effectSpecifiers.throwsSpecifier != nil {
                signature += " throws"
            }
        }
        
        // Return type
        if let returnClause = node.signature.returnClause {
            signature += " " + returnClause.description.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Generic where clause
        if let whereClause = node.genericWhereClause {
            signature += " " + whereClause.description.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return signature
    }
    
    private func generateVariableSignature(_ binding: PatternBindingSyntax, isLet: Bool) -> String {
        var signature = isLet ? "let " : "var "
        
        if let pattern = binding.pattern.as(IdentifierPatternSyntax.self) {
            signature += pattern.identifier.text
        }
        
        if let typeAnnotation = binding.typeAnnotation {
            signature += typeAnnotation.description.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return signature
    }
    
    private func generateInitializerSignature(_ node: InitializerDeclSyntax) -> String {
        var signature = "init"
        
        if let genericParams = node.genericParameterClause {
            signature += genericParams.description.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        signature += node.signature.parameterClause.description.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let effectSpecifiers = node.signature.effectSpecifiers {
            if effectSpecifiers.asyncSpecifier != nil {
                signature += " async"
            }
            if effectSpecifiers.throwsSpecifier != nil {
                signature += " throws"
            }
        }
        
        if let whereClause = node.genericWhereClause {
            signature += " " + whereClause.description.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return signature
    }
    
    private func generateSubscriptSignature(_ node: SubscriptDeclSyntax) -> String {
        var signature = "subscript"
        
        if let genericParams = node.genericParameterClause {
            signature += genericParams.description.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        signature += node.parameterClause.description.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // returnClause is not optional in SubscriptDeclSyntax
        signature += " " + node.returnClause.description.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let whereClause = node.genericWhereClause {
            signature += " " + whereClause.description.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return signature
    }
    
    private func generateTypeAliasSignature(_ node: TypeAliasDeclSyntax) -> String {
        var signature = "typealias \(node.name.text)"
        
        if let genericParams = node.genericParameterClause {
            signature += genericParams.description.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        signature += " = " + node.initializer.value.description.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let whereClause = node.genericWhereClause {
            signature += " " + whereClause.description.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return signature
    }
} 