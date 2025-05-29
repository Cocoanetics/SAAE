import Foundation
import SwiftSyntax
import SwiftParser
import Yams

/// Errors that can occur during SAAE operations
public enum SAAEError: Error, LocalizedError, Equatable {
    case fileNotFound(URL)
    case fileReadError(URL, Error)
    case parseError(String)
    case invalidASTHandle
    
    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let url):
            return "File not found at \(url.path)"
        case .fileReadError(let url, let error):
            return "Failed to read file at \(url.path): \(error.localizedDescription)"
        case .parseError(let message):
            return "Parse error: \(message)"
        case .invalidASTHandle:
            return "Invalid AST handle"
        }
    }
    
    public static func == (lhs: SAAEError, rhs: SAAEError) -> Bool {
        switch (lhs, rhs) {
        case (.fileNotFound(let lUrl), .fileNotFound(let rUrl)):
            return lUrl == rUrl
        case (.fileReadError(let lUrl, _), .fileReadError(let rUrl, _)):
            return lUrl == rUrl
        case (.parseError(let lMessage), .parseError(let rMessage)):
            return lMessage == rMessage
        case (.invalidASTHandle, .invalidASTHandle):
            return true
        default:
            return false
        }
    }
}

/// Main SAAE class for parsing Swift code and generating overviews
public class SAAE {
    
    // Internal storage for parsed ASTs
    private var astStorage: [UUID: SourceFileSyntax] = [:]
    
    public init() {}
    
    /// Parse Swift code from a file URL
    /// - Parameter fileURL: URL pointing to a local Swift source file
    /// - Returns: AST handle for the parsed code
    /// - Throws: SAAEError if file cannot be read or parsed
    public func parse(from_url fileURL: URL) throws -> ASTHandle {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw SAAEError.fileNotFound(fileURL)
        }
        
        let codeString: String
        do {
            codeString = try String(contentsOf: fileURL, encoding: .utf8)
        } catch {
            throw SAAEError.fileReadError(fileURL, error)
        }
        
        return try parse(from_string: codeString)
    }
    
    /// Parse Swift code from a string
    /// - Parameter codeString: String containing Swift source code
    /// - Returns: AST handle for the parsed code
    /// - Throws: SAAEError if code cannot be parsed
    public func parse(from_string codeString: String) throws -> ASTHandle {
        let sourceFile = Parser.parse(source: codeString)
        
        let handle = ASTHandle()
        astStorage[handle.id] = sourceFile
        return handle
    }
    
    /// Generate an overview of declarations in the parsed AST
    /// - Parameters:
    ///   - ast_handle: The AST handle obtained from a parse operation
    ///   - format: Output format (.json, .yaml, .markdown)
    ///   - min_visibility: Minimum visibility level to include
    /// - Returns: String containing the generated overview
    /// - Throws: SAAEError if AST handle is invalid
    public func generate_overview(
        ast_handle: ASTHandle,
        format: OutputFormat = .json,
        min_visibility: VisibilityLevel = .internal
    ) throws -> String {
        guard let sourceFile = astStorage[ast_handle.id] else {
            throw SAAEError.invalidASTHandle
        }
        
        let visitor = DeclarationVisitor(minVisibility: min_visibility)
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