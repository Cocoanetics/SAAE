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
    private var parentVisibility: VisibilityLevel = .internal
    
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
        let visibility = extractVisibility(from: node)
        guard visibility >= minVisibility else { return .skipChildren }
        
        currentIndex += 1
        let currentPath = generatePath()
        
        let name = node.name.text
        let fullName = generateFullName(name)
        let signature = generateFunctionSignature(node)
        let attributes = extractAttributes(from: node)
        let modifiers = extractModifiers(from: node)
        let documentation = extractDocumentation(from: node)
        
        let overview = DeclarationOverview(
            path: currentPath,
            type: "func",
            name: name,
            fullName: fullName,
            signature: signature,
            visibility: visibility.rawValue,
            modifiers: modifiers.isEmpty ? nil : modifiers,
            attributes: attributes.isEmpty ? nil : attributes,
            documentation: documentation
        )
        
        declarations.append(overview)
        return .skipChildren
    }
    
    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        let visibility = extractVisibility(from: node)
        guard visibility >= minVisibility else { return .skipChildren }
        
        let attributes = extractAttributes(from: node)
        let modifiers = extractModifiers(from: node)
        
        // Variables can have multiple bindings
        for binding in node.bindings {
            if let pattern = binding.pattern.as(IdentifierPatternSyntax.self) {
                currentIndex += 1
                let currentPath = generatePath()
                
                let name = pattern.identifier.text
                let fullName = generateFullName(name)
                let signature = generateVariableSignature(binding, isLet: node.bindingSpecifier.text == "let")
                let type = node.bindingSpecifier.text
                let documentation = extractDocumentation(from: node)
                
                let overview = DeclarationOverview(
                    path: currentPath,
                    type: type, // "var" or "let"
                    name: name,
                    fullName: fullName,
                    signature: signature,
                    visibility: visibility.rawValue,
                    modifiers: modifiers.isEmpty ? nil : modifiers,
                    attributes: attributes.isEmpty ? nil : attributes,
                    documentation: documentation
                )
                
                declarations.append(overview)
            }
        }
        return .skipChildren
    }
    
    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        let visibility = extractVisibility(from: node)
        guard visibility >= minVisibility else { return .skipChildren }
        
        currentIndex += 1
        let currentPath = generatePath()
        
        let name = "init"
        let fullName = generateFullName(name)
        let signature = generateInitializerSignature(node)
        let attributes = extractAttributes(from: node)
        let modifiers = extractModifiers(from: node)
        let documentation = extractDocumentation(from: node)
        
        let overview = DeclarationOverview(
            path: currentPath,
            type: "initializer",
            name: name,
            fullName: fullName,
            signature: signature,
            visibility: visibility.rawValue,
            modifiers: modifiers.isEmpty ? nil : modifiers,
            attributes: attributes.isEmpty ? nil : attributes,
            documentation: documentation
        )
        
        declarations.append(overview)
        return .skipChildren
    }
    
    override func visit(_ node: SubscriptDeclSyntax) -> SyntaxVisitorContinueKind {
        let visibility = extractVisibility(from: node)
        guard visibility >= minVisibility else { return .skipChildren }
        
        currentIndex += 1
        let currentPath = generatePath()
        
        let name = "subscript"
        let fullName = generateFullName(name)
        let signature = generateSubscriptSignature(node)
        let attributes = extractAttributes(from: node)
        let modifiers = extractModifiers(from: node)
        let documentation = extractDocumentation(from: node)
        
        let overview = DeclarationOverview(
            path: currentPath,
            type: "subscript",
            name: name,
            fullName: fullName,
            signature: signature,
            visibility: visibility.rawValue,
            modifiers: modifiers.isEmpty ? nil : modifiers,
            attributes: attributes.isEmpty ? nil : attributes,
            documentation: documentation
        )
        
        declarations.append(overview)
        return .skipChildren
    }
    
    override func visit(_ node: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind {
        return processTypeAlias(node)
    }
    
    override func visit(_ node: EnumCaseDeclSyntax) -> SyntaxVisitorContinueKind {
        // Enum cases don't have their own access modifiers - they inherit from their parent enum
        // Use parentVisibility instead of extracting from the case node
        let visibility = parentVisibility
        guard visibility >= minVisibility else { return .skipChildren }
        
        let attributes = extractAttributes(from: node)
        let modifiers = extractModifiers(from: node)
        
        for enumCase in node.elements {
            currentIndex += 1
            let currentPath = generatePath()
            
            let name = enumCase.name.text
            let fullName = generateFullName(name)
            let signature: String?
            
            if let parameters = enumCase.parameterClause {
                signature = "\(name)\(parameters.description.trimmingCharacters(in: .whitespacesAndNewlines))"
            } else {
                signature = name
            }
            
            let documentation = extractDocumentation(from: node)
            
            let overview = DeclarationOverview(
                path: currentPath,
                type: "case",
                name: name,
                fullName: fullName,
                signature: signature,
                visibility: visibility.rawValue,
                modifiers: modifiers.isEmpty ? nil : modifiers,
                attributes: attributes.isEmpty ? nil : attributes,
                documentation: documentation
            )
            
            declarations.append(overview)
        }
        return .skipChildren
    }
    
    // MARK: - Processing Methods
    
    private func processDeclaration<T: DeclSyntaxProtocol & NamedDeclSyntax>(_ node: T, type: String) {
        let visibility = extractVisibility(from: node)
        guard visibility >= minVisibility else { return }
        
        currentIndex += 1
        let currentPath = generatePath()
        
        let name = node.name.text
        let fullName = generateFullName(name)
        let attributes = extractAttributes(from: node)
        let modifiers = extractModifiers(from: node)
        let documentation = extractDocumentation(from: node)
        
        // Process members if this is a container type
        let members = processMembers(of: node, basePath: currentPath, parentName: fullName)
        
        let overview = DeclarationOverview(
            path: currentPath,
            type: type,
            name: name,
            fullName: fullName,
            signature: nil, // Container types don't have signatures in this implementation
            visibility: visibility.rawValue,
            modifiers: modifiers.isEmpty ? nil : modifiers,
            attributes: attributes.isEmpty ? nil : attributes,
            documentation: documentation,
            members: members.isEmpty ? nil : members
        )
        
        declarations.append(overview)
    }
    
    private func processExtension(_ node: ExtensionDeclSyntax) {
        let visibility = extractVisibility(from: node)
        
        currentIndex += 1
        let currentPath = generatePath()
        
        let extendedType = node.extendedType.description.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = extendedType
        let fullName = generateFullName(name)
        let attributes = extractAttributes(from: node)
        let modifiers = extractModifiers(from: node)
        let documentation = extractDocumentation(from: node)
        
        // Generate signature with protocol conformances if present
        let signature: String?
        if let inheritanceClause = node.inheritanceClause {
            let protocols = inheritanceClause.inheritedTypes.map { $0.type.description.trimmingCharacters(in: .whitespacesAndNewlines) }
            signature = "\(extendedType): \(protocols.joined(separator: ", "))"
        } else {
            signature = extendedType
        }
        
        // Process members of the extension first
        let members = processMembers(of: node, basePath: currentPath, parentName: fullName)
        
        // Only include the extension if it has visible members OR if the extension itself meets the visibility requirement
        guard !members.isEmpty || visibility >= minVisibility else { 
            // Decrement the index since we're not adding this extension
            currentIndex -= 1
            return 
        }
        
        let overview = DeclarationOverview(
            path: currentPath,
            type: "extension",
            name: name,
            fullName: fullName,
            signature: signature,
            visibility: visibility.rawValue,
            modifiers: modifiers.isEmpty ? nil : modifiers,
            attributes: attributes.isEmpty ? nil : attributes,
            documentation: documentation,
            members: members.isEmpty ? nil : members
        )
        
        declarations.append(overview)
    }
    
    private func processVariable(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        let visibility = extractVisibility(from: node)
        guard visibility >= minVisibility else { return .skipChildren }
        
        let attributes = extractAttributes(from: node)
        let modifiers = extractModifiers(from: node)
        
        // Variables can have multiple bindings
        for binding in node.bindings {
            if let pattern = binding.pattern.as(IdentifierPatternSyntax.self) {
                currentIndex += 1
                let currentPath = generatePath()
                
                let name = pattern.identifier.text
                let fullName = generateFullName(name)
                let signature = generateVariableSignature(binding, isLet: node.bindingSpecifier.text == "let")
                let type = node.bindingSpecifier.text
                let documentation = extractDocumentation(from: node)
                
                let overview = DeclarationOverview(
                    path: currentPath,
                    type: type, // "var" or "let"
                    name: name,
                    fullName: fullName,
                    signature: signature,
                    visibility: visibility.rawValue,
                    modifiers: modifiers.isEmpty ? nil : modifiers,
                    attributes: attributes.isEmpty ? nil : attributes,
                    documentation: documentation
                )
                
                declarations.append(overview)
            }
        }
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
        let attributes = extractAttributes(from: node)
        let modifiers = extractModifiers(from: node)
        let documentation = extractDocumentation(from: node)
        
        let overview = DeclarationOverview(
            path: currentPath,
            type: "subscript",
            name: name,
            fullName: fullName,
            signature: signature,
            visibility: visibility.rawValue,
            modifiers: modifiers.isEmpty ? nil : modifiers,
            attributes: attributes.isEmpty ? nil : attributes,
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
        let attributes = extractAttributes(from: node)
        let modifiers = extractModifiers(from: node)
        let documentation = extractDocumentation(from: node)
        
        let overview = DeclarationOverview(
            path: currentPath,
            type: "typealias",
            name: name,
            fullName: fullName,
            signature: signature,
            visibility: visibility.rawValue,
            modifiers: modifiers.isEmpty ? nil : modifiers,
            attributes: attributes.isEmpty ? nil : attributes,
            documentation: documentation
        )
        
        declarations.append(overview)
        return .skipChildren
    }
    
    // MARK: - Helper Methods
    
    private func processMembers<T: SyntaxProtocol>(of node: T, basePath: String, parentName: String) -> [DeclarationOverview] {
        // Create a new visitor for members
        let memberVisitor = DeclarationVisitor(minVisibility: minVisibility)
        memberVisitor.pathComponents = pathComponents + [currentIndex]
        memberVisitor.currentIndex = 0
        memberVisitor.parentNames = parentNames + [parentName.components(separatedBy: ".").last ?? parentName]
        
        // Pass parent visibility for inheritance
        if let enumDecl = node.as(EnumDeclSyntax.self) {
            memberVisitor.parentVisibility = extractVisibility(from: enumDecl)
        } else if let structDecl = node.as(StructDeclSyntax.self) {
            memberVisitor.parentVisibility = extractVisibility(from: structDecl)
        } else if let classDecl = node.as(ClassDeclSyntax.self) {
            memberVisitor.parentVisibility = extractVisibility(from: classDecl)
        } else if let protocolDecl = node.as(ProtocolDeclSyntax.self) {
            memberVisitor.parentVisibility = extractVisibility(from: protocolDecl)
        } else if let extensionDecl = node.as(ExtensionDeclSyntax.self) {
            memberVisitor.parentVisibility = extractVisibility(from: extensionDecl)
        }
        
        // Find the member block
        if let memberBlock = findMemberBlock(in: node) {
            memberVisitor.walk(memberBlock)
        }
        
        return memberVisitor.declarations
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
    
    private func extractAttributes<T: SyntaxProtocol>(from node: T) -> [String] {
        // Try to extract attributes from different declaration types
        var attributes: AttributeListSyntax?
        
        if let structDecl = node.as(StructDeclSyntax.self) {
            attributes = structDecl.attributes
        } else if let classDecl = node.as(ClassDeclSyntax.self) {
            attributes = classDecl.attributes
        } else if let enumDecl = node.as(EnumDeclSyntax.self) {
            attributes = enumDecl.attributes
        } else if let protocolDecl = node.as(ProtocolDeclSyntax.self) {
            attributes = protocolDecl.attributes
        } else if let extensionDecl = node.as(ExtensionDeclSyntax.self) {
            attributes = extensionDecl.attributes
        } else if let functionDecl = node.as(FunctionDeclSyntax.self) {
            attributes = functionDecl.attributes
        } else if let variableDecl = node.as(VariableDeclSyntax.self) {
            attributes = variableDecl.attributes
        } else if let initDecl = node.as(InitializerDeclSyntax.self) {
            attributes = initDecl.attributes
        } else if let subscriptDecl = node.as(SubscriptDeclSyntax.self) {
            attributes = subscriptDecl.attributes
        } else if let typeAliasDecl = node.as(TypeAliasDeclSyntax.self) {
            attributes = typeAliasDecl.attributes
        }
        
        guard let attributes = attributes else {
            return []
        }
        
        var attributeStrings: [String] = []
        
        for attribute in attributes {
            if let attr = attribute.as(AttributeSyntax.self) {
                let attributeText = normalizeWhitespace(attr.description)
                attributeStrings.append(attributeText)
            }
        }
        
        return attributeStrings
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
        var signature = ""
        
        // Add modifiers (excluding visibility which is handled separately)
        let modifiers = extractModifiers(from: node)
        if !modifiers.isEmpty {
            signature += modifiers.joined(separator: " ") + " "
        }
        
        signature += "func \(node.name.text)"
        
        // Generic parameters
        if let genericParams = node.genericParameterClause {
            let normalized = normalizeWhitespace(genericParams.description)
            signature += normalized
        }
        
        // Parameters
        let params = normalizeWhitespace(node.signature.parameterClause.description)
        signature += params
        
        // Async/throws
        if let effectSpecifiers = node.signature.effectSpecifiers {
            if effectSpecifiers.asyncSpecifier != nil {
                signature += " async"
            }
            if effectSpecifiers.throwsClause?.throwsSpecifier != nil {
                signature += " throws"
            }
        }
        
        // Return type
        if let returnClause = node.signature.returnClause {
            let normalized = normalizeWhitespace(returnClause.description)
            signature += " " + normalized
        }
        
        // Generic where clause
        if let whereClause = node.genericWhereClause {
            let normalized = normalizeWhitespace(whereClause.description)
            signature += " " + normalized
        }
        
        return signature
    }
    
    /// Normalizes whitespace in a string to single-line format
    private func normalizeWhitespace(_ text: String) -> String {
        return text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
    
    private func generateVariableSignature(_ binding: PatternBindingSyntax, isLet: Bool) -> String {
        var signature = isLet ? "let " : "var "
        
        if let pattern = binding.pattern.as(IdentifierPatternSyntax.self) {
            signature += pattern.identifier.text
        }
        
        if let typeAnnotation = binding.typeAnnotation {
            let normalized = normalizeWhitespace(typeAnnotation.description)
            signature += normalized
        } else if let initializer = binding.initializer {
            // Try to infer type from initializer for better readability
            let initText = initializer.value.description.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Handle common cases for type inference
            if initText.starts(with: "Configuration(") {
                signature += ": Configuration"
            } else if initText.contains("Double(") || initText.hasSuffix(".0") {
                signature += ": Double"
            } else if initText.contains("Int(") || (initText.allSatisfy { $0.isNumber }) {
                signature += ": Int"
            } else if initText.starts(with: "\"") && initText.hasSuffix("\"") {
                signature += ": String"
            } else if initText == "true" || initText == "false" {
                signature += ": Bool"
            }
            // For complex initializers, we could try to extract the type name
            // from the beginning of the initializer expression
        }
        
        return signature
    }
    
    private func generateInitializerSignature(_ node: InitializerDeclSyntax) -> String {
        var signature = "init"
        
        if let genericParams = node.genericParameterClause {
            let normalized = normalizeWhitespace(genericParams.description)
            signature += normalized
        }
        
        let params = normalizeWhitespace(node.signature.parameterClause.description)
        signature += params
        
        if let effectSpecifiers = node.signature.effectSpecifiers {
            if effectSpecifiers.asyncSpecifier != nil {
                signature += " async"
            }
            if effectSpecifiers.throwsClause?.throwsSpecifier != nil {
                signature += " throws"
            }
        }
        
        if let whereClause = node.genericWhereClause {
            let normalized = normalizeWhitespace(whereClause.description)
            signature += " " + normalized
        }
        
        return signature
    }
    
    private func generateSubscriptSignature(_ node: SubscriptDeclSyntax) -> String {
        var signature = "subscript"
        
        if let genericParams = node.genericParameterClause {
            let normalized = normalizeWhitespace(genericParams.description)
            signature += normalized
        }
        
        let params = normalizeWhitespace(node.parameterClause.description)
        signature += params
        
        // returnClause is not optional in SubscriptDeclSyntax
        let returnType = normalizeWhitespace(node.returnClause.description)
        signature += " " + returnType
        
        if let whereClause = node.genericWhereClause {
            let normalized = normalizeWhitespace(whereClause.description)
            signature += " " + normalized
        }
        
        return signature
    }
    
    private func generateTypeAliasSignature(_ node: TypeAliasDeclSyntax) -> String {
        var signature = "typealias \(node.name.text)"
        
        if let genericParams = node.genericParameterClause {
            let normalized = normalizeWhitespace(genericParams.description)
            signature += normalized
        }
        
        let initializer = normalizeWhitespace(node.initializer.value.description)
        signature += " = " + initializer
        
        if let whereClause = node.genericWhereClause {
            let normalized = normalizeWhitespace(whereClause.description)
            signature += " " + normalized
        }
        
        return signature
    }
    
    private func extractModifiers<T: SyntaxProtocol>(from node: T) -> [String] {
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
            return []
        }
        
        var modifierStrings: [String] = []
        
        for modifier in modifiers {
            let modifierName = modifier.name.text
            // Skip visibility modifiers as they're handled separately
            if !["private", "fileprivate", "internal", "package", "public", "open"].contains(modifierName) {
                modifierStrings.append(modifierName)
            }
        }
        
        return modifierStrings
    }
} 
