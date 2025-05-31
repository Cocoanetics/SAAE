import Foundation
import SwiftSyntax

/// Syntax rewriter that converts private/fileprivate access modifiers to internal
/// when extracting declarations to separate files
private class AccessControlRewriter: SyntaxRewriter {
    
    override func visit(_ node: DeclModifierSyntax) -> DeclModifierSyntax {
        // Check if this is a private or fileprivate modifier
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
        
        guard !declarations.isEmpty else {
            // No declarations found - return original file unchanged
            let originalContent = tree.sourceFile.description
            let originalFile = GeneratedFile(
                fileName: originalFileName,
                content: originalContent,
                imports: imports,
                declarations: []
            )
            return DistributionResult(modifiedOriginalFile: originalFile, newFiles: [])
        }
        
        if declarations.count == 1 {
            // Only one declaration, keep original file unchanged
            let originalContent = tree.sourceFile.description
            let originalFile = GeneratedFile(
                fileName: originalFileName,
                content: originalContent,
                imports: imports,
                declarations: declarations
            )
            return DistributionResult(modifiedOriginalFile: originalFile, newFiles: [])
        }
        
        // Multiple declarations: keep first, extract others
        let firstDeclaration = declarations[0]
        let declarationsToExtract = Array(declarations.dropFirst())
        
        // Create modified source file with extracted declarations removed
        let modifiedSourceFile = try removeDeclarations(declarationsToExtract, from: tree.sourceFile)
        
        // Apply access control fixes to the modified original file (make private/fileprivate → internal)
        let accessControlRewriter = AccessControlRewriter()
        let fixedModifiedSourceFile = accessControlRewriter.visit(modifiedSourceFile)
        
        // Generate modified original file with only the first declaration (and imports)
        let modifiedOriginalContent = fixedModifiedSourceFile.description
        let modifiedOriginalFile = GeneratedFile(
            fileName: originalFileName,
            content: modifiedOriginalContent,
            imports: imports,
            declarations: [firstDeclaration]
        )
        
        // Generate new files for extracted declarations
        var newFiles: [GeneratedFile] = []
        
        for declaration in declarationsToExtract {
            let fileName = generateFileName(for: declaration, tree: tree)
            let content = try generateFileContentForDeclaration(declaration, imports: imports, sourceFile: tree.sourceFile)
            
            let newFile = GeneratedFile(
                fileName: fileName,
                content: content,
                imports: imports,
                declarations: [declaration]
            )
            newFiles.append(newFile)
        }
        
        return DistributionResult(modifiedOriginalFile: modifiedOriginalFile, newFiles: newFiles)
    }
    
    /// Removes specific declarations from a source file
    private func removeDeclarations(_ declarationsToRemove: [DeclarationOverview], from sourceFile: SourceFileSyntax) throws -> SourceFileSyntax {
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
    private func generateFileContentForDeclaration(_ declaration: DeclarationOverview, imports: [String], sourceFile: SourceFileSyntax) throws -> String {
        var content = ""
        
        // Add imports
        for importName in imports {
            content += "import \(importName)\n"
        }
        
        if !imports.isEmpty {
            content += "\n"
        }
        
        // Add the target declaration
        if let declSyntax = findDeclarationSyntax(for: declaration, in: sourceFile) {
            // Apply access control rewriting for extracted declarations
            let rewriter = AccessControlRewriter()
            let rewrittenDecl = rewriter.visit(declSyntax)
            content += rewrittenDecl.description
        }
        
        return content
    }
    
    /// Generates appropriate filename for a declaration
    private func generateFileName(for declaration: DeclarationOverview, tree: SyntaxTree) -> String {
        if declaration.type == "extension" {
            return generateExtensionFileName(for: declaration, tree: tree)
        } else {
            return "\(declaration.name).swift"
        }
    }
    
    /// Generates filename for extension declarations
    private func generateExtensionFileName(for declaration: DeclarationOverview, tree: SyntaxTree) -> String {
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
    private struct ExtensionInfo {
        let typeName: String
        let protocols: [String]
    }
    
    /// Extracts type name and protocol conformances from an extension
    private func extractExtensionInfo(for declaration: DeclarationOverview, tree: SyntaxTree) -> ExtensionInfo? {
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
    private func findDeclarationSyntax(for declaration: DeclarationOverview, in sourceFile: SourceFileSyntax) -> DeclSyntax? {
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
} 