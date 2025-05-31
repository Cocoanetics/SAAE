import Foundation
import SwiftSyntax

/// Syntax rewriter that converts private/fileprivate access modifiers to internal
/// when extracting declarations to separate files
private class AccessControlRewriter: SyntaxRewriter {
    
	override func visit(_ node: DeclModifierListSyntax) -> DeclModifierListSyntax {
        let filtered = node.filter { modifier in
            if let detail = modifier.detail,
               detail.detail.text == "set",
               ["private", "fileprivate", "internal"].contains(modifier.name.text) {
                return false // Remove this modifier
            }
            return true
        }
        return filtered
    }

    override func visit(_ node: DeclModifierSyntax) -> DeclModifierSyntax {
        // Check if this is a private or fileprivate modifier (without detail)
        if node.name.tokenKind == .keyword(.private) || node.name.tokenKind == .keyword(.fileprivate) {
            // Replace with internal, preserving the original trivia (spacing)
            let newToken = TokenSyntax(.keyword(.internal), 
                                     leadingTrivia: node.name.leadingTrivia,
                                     trailingTrivia: node.name.trailingTrivia,
                                     presence: .present)
            return node.with(\.name, newToken)
        }
        return super.visit(node)
    }
}

/// Result of code distribution operation
public struct DistributionResult {
    /// The modified original file with extracted declarations removed
    public let modifiedOriginalFile: GeneratedFile?
    
    /// New files created for the extracted declarations
    public let newFiles: [GeneratedFile]
    
    public init(modifiedOriginalFile: GeneratedFile?, newFiles: [GeneratedFile]) {
        self.modifiedOriginalFile = modifiedOriginalFile
        self.newFiles = newFiles
    }
}

/// Represents a generated Swift source file
public struct GeneratedFile {
    /// The filename (including .swift extension)
    public let fileName: String
    
    /// The complete source code content
    public let content: String
    
    /// The import statements included in this file
    public let imports: [String]
    
    /// The declarations included in this file
    public let declarations: [DeclarationOverview]
    
    public init(fileName: String, content: String, imports: [String], declarations: [DeclarationOverview]) {
        self.fileName = fileName
        self.content = content
        self.imports = imports
        self.declarations = declarations
    }
}

/// Distributes Swift declarations across multiple files
public class CodeDistributor {
    
    public init() {}
    
    /// Distributes declarations from a source file, keeping the first declaration in the original file
    /// and moving all others to appropriately named separate files.
    ///
    /// - Parameters:
    ///   - tree: The syntax tree to distribute
    ///   - originalFileName: The original filename to use for the modified file
    /// - Returns: Distribution result with modified original file and new files
    /// - Throws: Distribution errors
    public func distributeKeepingFirst(tree: SyntaxTree, originalFileName: String) throws -> DistributionResult {
        // Extract imports and declarations
        let overview = CodeOverview(tree: tree, minVisibility: .private) // Include all declarations
        let imports = overview.imports
        let declarations = overview.declarations
        
        // Separate type vs non-type declarations
        var typeDeclarations: [DeclarationOverview] = []
        var nonTypeDeclarations: [DeclarationOverview] = []
        for decl in declarations {
            if let declSyntax = findDeclarationSyntax(for: decl, in: tree.sourceFile), isTypeDeclaration(declSyntax) {
                typeDeclarations.append(decl)
            } else {
                nonTypeDeclarations.append(decl)
            }
        }
        
        // Build files for type declarations, merging multiple extensions with the same filename
        var fileBuilders: [String: (content: String, declarations: [DeclarationOverview])] = [:]
        let importHeader: String = {
            guard !imports.isEmpty else { return "" }
            return imports.map { "import \($0)" }.joined(separator: "\n") + "\n\n"
        }()
        
        for declaration in typeDeclarations {
            let fileName = generateFileName(for: declaration, tree: tree)
            let declSource = generateDeclarationSource(declaration, in: tree.sourceFile)
            if var builder = fileBuilders[fileName] {
                builder.content += "\n\n" + declSource
                builder.declarations.append(declaration)
                fileBuilders[fileName] = builder
            } else {
                let initialContent = importHeader + declSource
                fileBuilders[fileName] = (initialContent, [declaration])
            }
        }
        
        let newFiles: [GeneratedFile] = fileBuilders.map { key, value in
            GeneratedFile(fileName: key, content: value.content, imports: imports, declarations: value.declarations)
        }
        
        // Build modified original file (for non-type code)
        var modifiedOriginalFile: GeneratedFile? = nil
        if !nonTypeDeclarations.isEmpty {
            let content = try generateFileContent(imports: imports, targetDeclarations: nonTypeDeclarations, sourceFile: tree.sourceFile)
            modifiedOriginalFile = GeneratedFile(fileName: originalFileName, content: content, imports: imports, declarations: nonTypeDeclarations)
        }
        
        return DistributionResult(modifiedOriginalFile: modifiedOriginalFile, newFiles: newFiles)
    }
    
    /// Removes specific declarations from a source file
    internal func removeDeclarations(_ declarationsToRemove: [DeclarationOverview], from sourceFile: SourceFileSyntax) throws -> SourceFileSyntax {
        // Get the indices of declarations to remove (1-based paths converted to 0-based indices)
        let indicesToRemove = Set(declarationsToRemove.compactMap { declaration -> Int? in
            let pathComponents = declaration.path.split(separator: ".").compactMap { Int($0) }
            guard let firstIndex = pathComponents.first, firstIndex > 0 else { return nil }
            
            // Convert to 0-based index in declaration statements (not all statements)
            return firstIndex - 1
        })
        
        // Filter statements to remove target declarations
        var newStatements: [CodeBlockItemSyntax] = []
        var declarationIndex = 0
        
        for statement in sourceFile.statements {
            // Check if this is a declaration statement (not import or other)
            if let declSyntax = statement.item.as(DeclSyntax.self) {
                // Skip import declarations - they don't count towards declaration indices
                if declSyntax.is(ImportDeclSyntax.self) {
                    newStatements.append(statement)
                    continue
                }
                
                // Check if this declaration should be removed
                if indicesToRemove.contains(declarationIndex) {
                    // Skip this declaration (remove it)
                    declarationIndex += 1
                    continue
                } else {
                    // Keep this declaration
                    newStatements.append(statement)
                    declarationIndex += 1
                }
            } else {
                // Non-declaration statement, keep it
                newStatements.append(statement)
            }
        }
        
        // Create new source file with modified statements
        return sourceFile.with(\.statements, CodeBlockItemListSyntax(newStatements))
    }
    
    /// Generates file content for a single declaration
    internal func generateFileContentForDeclaration(_ declaration: DeclarationOverview, imports: [String], sourceFile: SourceFileSyntax) throws -> String {
        var content = ""
        // Add imports
        if !imports.isEmpty {
            for importName in imports {
                content += "import \(importName)\n"
            }
            content += "\n" // Only one newline after all imports
        }
        // Add the target declaration
        if let declSyntax = findDeclarationSyntax(for: declaration, in: sourceFile) {
            // Apply access control rewriting for extracted declarations
            let rewriter = AccessControlRewriter()
            let rewrittenDecl = rewriter.visit(declSyntax)
            var declString = rewrittenDecl.description
            declString = declString.trimmingCharacters(in: .newlines)
            content += declString
        }
        return content
    }
    
    /// Generates appropriate filename for a declaration
    internal func generateFileName(for declaration: DeclarationOverview, tree: SyntaxTree) -> String {
        if declaration.type == "extension" {
            return generateExtensionFileName(for: declaration, tree: tree)
        } else {
            return "\(declaration.name).swift"
        }
    }
    
    /// Generates filename for extension declarations
    internal func generateExtensionFileName(for declaration: DeclarationOverview, tree: SyntaxTree) -> String {
        // Try to extract the extended type name and protocol conformances
        if let extensionInfo = extractExtensionInfo(for: declaration, tree: tree) {
            if !extensionInfo.protocols.isEmpty {
                // Extension with protocol conformance: Type+Protocol.swift
                let protocolName = extensionInfo.protocols.joined(separator: "+")
                return "\(extensionInfo.typeName)+\(protocolName).swift"
            } else {
                // Extension without protocol: Type+Extensions.swift
                return "\(extensionInfo.typeName)+Extensions.swift"
            }
        } else {
            // Fallback
            return "\(declaration.name)+Extensions.swift"
        }
    }
    
    /// Information extracted from an extension declaration
    internal struct ExtensionInfo {
        let typeName: String
        let protocols: [String]
    }
    
    /// Extracts type name and protocol conformances from an extension
    internal func extractExtensionInfo(for declaration: DeclarationOverview, tree: SyntaxTree) -> ExtensionInfo? {
        // Find the extension syntax node using the declaration path
        guard let declSyntax = findDeclarationSyntax(for: declaration, in: tree.sourceFile) else {
            return nil
        }
        
        // Try to cast to ExtensionDeclSyntax
        guard let extensionNode = declSyntax.as(ExtensionDeclSyntax.self) else {
            return nil
        }
        
        let typeName = extensionNode.extendedType.description.trimmingCharacters(in: .whitespacesAndNewlines)
        
        var protocols: [String] = []
        if let inheritanceClause = extensionNode.inheritanceClause {
            for inheritedType in inheritanceClause.inheritedTypes {
                let protocolName = inheritedType.type.description.trimmingCharacters(in: .whitespacesAndNewlines)
                protocols.append(protocolName)
            }
        }
        
        return ExtensionInfo(typeName: typeName, protocols: protocols)
    }
    
    /// Finds the syntax node for a declaration using its path
    internal func findDeclarationSyntax(for declaration: DeclarationOverview, in sourceFile: SourceFileSyntax) -> DeclSyntax? {
        let pathComponents = declaration.path.split(separator: ".").compactMap { Int($0) }
        
        guard let firstIndex = pathComponents.first, firstIndex > 0 else { return nil }
        
        // Filter to only declaration statements (not imports or other statements)
        let declarationStatements = sourceFile.statements.compactMap { statement -> DeclSyntax? in
            // Skip import declarations and other non-declaration statements
            if let declSyntax = statement.item.as(DeclSyntax.self) {
                // Check if it's an import declaration
                if declSyntax.is(ImportDeclSyntax.self) {
                    return nil // Skip imports
                }
                return declSyntax
            }
            return nil
        }
        
        guard firstIndex <= declarationStatements.count else { return nil }
        
        return declarationStatements[firstIndex - 1]
    }
    
    /// Determines whether a declaration is considered a core infrastructure type that should never be extracted.
    internal func isCoreDeclaration(_ declaration: DeclarationOverview) -> Bool {
        // Core infrastructure types that are referenced widely across multiple files
        let coreTypeNames: Set<String> = [
            "FileOverview",
            "DistributionResult",
            "GeneratedFile",
            "MultiFileCodeOverview",
            "PathNavigator",
            "AccessControlRewriter"
        ]
        return coreTypeNames.contains(declaration.name)
    }
    
    /// Returns true if the given DeclSyntax is a type declaration (class, struct, enum, protocol, actor, extension)
    private func isTypeDeclaration(_ decl: DeclSyntax) -> Bool {
        return decl.is(ClassDeclSyntax.self) ||
               decl.is(StructDeclSyntax.self) ||
               decl.is(EnumDeclSyntax.self) ||
               decl.is(ProtocolDeclSyntax.self) ||
               decl.is(ActorDeclSyntax.self) ||
               decl.is(ExtensionDeclSyntax.self)
    }
    
    /// Generates the complete source file content for given imports and specific target declarations
    private func generateFileContent(imports: [String], targetDeclarations: [DeclarationOverview], sourceFile: SourceFileSyntax) throws -> String {
        var content = ""
        // Add imports
        if !imports.isEmpty {
            for importName in imports {
                content += "import \(importName)\n"
            }
            content += "\n" // Only one newline after all imports
        }
        // Add only the target declarations
        for (index, targetDeclaration) in targetDeclarations.enumerated() {
            if let declSyntax = findDeclarationSyntax(for: targetDeclaration, in: sourceFile) {
                // Remove leading newlines from the declaration
                var declString = declSyntax.description
                declString = declString.trimmingCharacters(in: .newlines)
                content += declString
                if index < targetDeclarations.count - 1 {
                    content += "\n\n"
                }
            }
        }
        return content
    }
    
    /// Generates source text for a declaration (without import headers)
    internal func generateDeclarationSource(_ declaration: DeclarationOverview, in sourceFile: SourceFileSyntax) -> String {
        guard let declSyntax = findDeclarationSyntax(for: declaration, in: sourceFile) else {
            return ""
        }
        // Always apply AccessControlRewriter to the whole declaration (including top-level types)
        let rewriter = AccessControlRewriter()
        let rewrittenDecl = rewriter.visit(declSyntax)
        return rewrittenDecl.description.trimmingCharacters(in: .newlines)
    }
} 

