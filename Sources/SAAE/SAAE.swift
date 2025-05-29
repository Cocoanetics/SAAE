import Foundation
import SwiftSyntax
import SwiftParser
import Yams

/// Main SAAE class for parsing Swift code and generating overviews
public class SAAE {
    
    // Internal storage for parsed ASTs
    private var astStorage: [UUID: SourceFileSyntax] = [:]
    
    public init() {}
    
    /// Parse Swift code from a file URL
    /// - Parameter url: URL pointing to a local Swift source file
    /// - Returns: AST handle for the parsed code
    /// - Throws: SAAEError if file cannot be read or parsed
    public func parse(url: URL) throws -> ASTHandle {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw SAAEError.fileNotFound(url)
        }
        
        let codeString: String
        do {
            codeString = try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw SAAEError.fileReadError(url, error)
        }
        
        return try parse(string: codeString)
    }
    
    /// Parse Swift code from a string
    /// - Parameter string: String containing Swift source code
    /// - Returns: AST handle for the parsed code
    /// - Throws: SAAEError if code cannot be parsed
    public func parse(string: String) throws -> ASTHandle {
        let sourceFile = Parser.parse(source: string)
        
        let handle = ASTHandle()
        astStorage[handle.id] = sourceFile
        return handle
    }
    
    /// Generate an overview of declarations in the parsed AST
    /// - Parameters:
    ///   - astHandle: The AST handle obtained from a parse operation
    ///   - format: Output format (.json, .yaml, .markdown)
    ///   - minVisibility: Minimum visibility level to include
    /// - Returns: String containing the generated overview
    /// - Throws: SAAEError if AST handle is invalid
    public func generateOverview(
        astHandle: ASTHandle,
        format: OutputFormat = .json,
        minVisibility: VisibilityLevel = .internal
    ) throws -> String {
        guard let sourceFile = astStorage[astHandle.id] else {
            throw SAAEError.invalidASTHandle
        }
        
        let visitor = DeclarationVisitor(minVisibility: minVisibility)
        visitor.walk(sourceFile)
        
        let overviews = visitor.declarations
        
        switch format {
        case .json:
            return try generateJSONOutput(overviews)
        case .yaml:
            return try generateYAMLOutput(overviews)
        case .markdown:
            return generateMarkdownOutput(overviews)
        }
    }
    
    // MARK: - Private Output Generation Methods
    
    private func generateJSONOutput(_ overviews: [DeclarationOverview]) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(overviews)
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    private func generateYAMLOutput(_ overviews: [DeclarationOverview]) throws -> String {
        let encoder = YAMLEncoder()
        return try encoder.encode(overviews)
    }
    
    private func generateMarkdownOutput(_ overviews: [DeclarationOverview]) -> String {
        var markdown = "# Code Overview\n\n"
        
        func addDeclaration(_ decl: DeclarationOverview, level: Int = 2) {
            let heading = String(repeating: "#", count: level)
            let title = decl.fullName ?? decl.name
            markdown += "\(heading) \(decl.type.capitalized): \(title)\n\n"
            
            markdown += "**Path:** `\(decl.path)`  \n"
            markdown += "**Visibility:** `\(decl.visibility)`  \n"
            
            if let signature = decl.signature {
                markdown += "**Signature:** `\(signature)`  \n"
            }
            
            markdown += "\n"
            
            if let documentation = decl.documentation {
                if !documentation.description.isEmpty {
                    markdown += "\(documentation.description)\n\n"
                }
                
                if !documentation.parameters.isEmpty {
                    markdown += "**Parameters:**\n"
                    for (name, desc) in documentation.parameters.sorted(by: { $0.key < $1.key }) {
                        markdown += "- `\(name)`: \(desc)\n"
                    }
                    markdown += "\n"
                }
                
                if let returns = documentation.returns {
                    markdown += "**Returns:** \(returns)\n\n"
                }
            }
            
            if let childPaths = decl.childPaths, !childPaths.isEmpty {
                markdown += "**Children:**\n"
                for childPath in childPaths {
                    markdown += "- Path: `\(childPath)`\n"
                }
                markdown += "\n"
            }
            
            markdown += "---\n\n"
        }
        
        func processDeclarations(_ declarations: [DeclarationOverview]) {
            for decl in declarations {
                addDeclaration(decl)
                if let members = decl.members {
                    processDeclarations(members)
                }
            }
        }
        
        processDeclarations(overviews)
        return markdown
    }
} 