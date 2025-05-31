import Foundation
import SwiftSyntax

/// Result of code distribution operation
public struct DistributionResult {
    /// The modified original file (keeping only first declaration)
    public let originalFile: GeneratedFile?
    
    /// New files created for the remaining declarations
    public let newFiles: [GeneratedFile]
    
    public init(originalFile: GeneratedFile?, newFiles: [GeneratedFile]) {
        self.originalFile = originalFile
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
    /// - Parameter tree: The syntax tree to distribute
    /// - Returns: Distribution result with original file and new files
    /// - Throws: Distribution errors
    public func distributeKeepingFirst(tree: SyntaxTree) throws -> DistributionResult {
        // Extract imports and declarations
        let overview = CodeOverview(tree: tree, minVisibility: .private) // Include all declarations
        let imports = overview.imports
        let declarations = overview.declarations
        
        guard !declarations.isEmpty else {
            // No declarations found
            return DistributionResult(originalFile: nil, newFiles: [])
        }
        
        if declarations.count == 1 {
            // Only one declaration, keep it in original file
            let originalContent = try generateFileContent(imports: imports, targetDeclarations: declarations, sourceFile: tree.sourceFile)
            let originalFile = GeneratedFile(
                fileName: "Original.swift", // Placeholder name
                content: originalContent,
                imports: imports,
                declarations: declarations
            )
            return DistributionResult(originalFile: originalFile, newFiles: [])
        }
        
        // Multiple declarations: keep first, move others
        let firstDeclaration = declarations[0]
        let remainingDeclarations = Array(declarations.dropFirst())
        
        // Generate original file with only first declaration
        let originalContent = try generateFileContent(
            imports: imports, 
            targetDeclarations: [firstDeclaration], 
            sourceFile: tree.sourceFile
        )
        let originalFile = GeneratedFile(
            fileName: "Original.swift", // Placeholder name
            content: originalContent,
            imports: imports,
            declarations: [firstDeclaration]
        )
        
        // Generate new files for remaining declarations
        var newFiles: [GeneratedFile] = []
        
        for declaration in remainingDeclarations {
            let fileName = generateFileName(for: declaration, tree: tree)
            let content = try generateFileContent(
                imports: imports, 
                targetDeclarations: [declaration], 
                sourceFile: tree.sourceFile
            )
            
            let newFile = GeneratedFile(
                fileName: fileName,
                content: content,
                imports: imports,
                declarations: [declaration]
            )
            newFiles.append(newFile)
        }
        
        return DistributionResult(originalFile: originalFile, newFiles: newFiles)
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
    
    /// Generates the complete source file content for given imports and specific target declarations
    private func generateFileContent(imports: [String], targetDeclarations: [DeclarationOverview], sourceFile: SourceFileSyntax) throws -> String {
        var content = ""
        
        // Add imports
        for importName in imports {
            content += "import \(importName)\n"
        }
        
        if !imports.isEmpty {
            content += "\n"
        }
        
        // Add only the target declarations
        for (index, targetDeclaration) in targetDeclarations.enumerated() {
            if let declSyntax = findDeclarationSyntax(for: targetDeclaration, in: sourceFile) {
                // Add the original syntax with proper formatting
                let declString = declSyntax.description
                content += declString
                
                if index < targetDeclarations.count - 1 {
                    content += "\n\n"
                }
            }
        }
        
        return content
    }
} 