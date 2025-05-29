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
    ///   - format: Output format (.json, .yaml, .markdown, .interface)
    ///   - minVisibility: Minimum visibility level to include
    /// - Returns: String containing the generated overview
    /// - Throws: SAAEError if AST handle is invalid
    public func generateOverview(
        astHandle: ASTHandle,
        format: OutputFormat = .json,
        minVisibility: SAAE.VisibilityLevel = .internal
    ) throws -> String {
        guard let sourceFile = astStorage[astHandle.id] else {
            throw SAAEError.invalidASTHandle
        }
        
        // Collect imports first
        let importVisitor = ImportVisitor()
        importVisitor.walk(sourceFile)
        let imports = importVisitor.imports
        
        let visitor = DeclarationVisitor(minVisibility: minVisibility)
        visitor.walk(sourceFile)
        
        let overviews = visitor.declarations
        let codeOverview = CodeOverview(imports: imports.sorted(), declarations: overviews)
        
        switch format {
        case .json:
            return try generateJSONOutput(codeOverview)
        case .yaml:
            return try generateYAMLOutput(codeOverview)
        case .markdown:
            return generateMarkdownOutput(codeOverview)
        case .interface:
            return generateInterfaceOutput(overviews, imports: imports)
        }
    }
    
    // MARK: - Private Output Generation Methods
    
    private func generateJSONOutput(_ codeOverview: CodeOverview) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(codeOverview)
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    private func generateYAMLOutput(_ codeOverview: CodeOverview) throws -> String {
        let encoder = YAMLEncoder()
        return try encoder.encode(codeOverview)
    }
    
    private func generateInterfaceOutput(_ overviews: [DeclarationOverview], imports: [String]) -> String {
        var interface = ""
        
        // Add imports at the top
        for importName in imports.sorted() {
            interface += "import \(importName)\n"
        }
        
        if !imports.isEmpty {
            interface += "\n"
        }
        
        func addDeclaration(_ decl: DeclarationOverview, indentLevel: Int = 0) {
            let indent = String(repeating: "   ", count: indentLevel)
            
            // Add attributes if present (property wrappers, Swift macros, etc.)
            if let attributes = decl.attributes, !attributes.isEmpty {
                for attribute in attributes {
                    interface += "\(indent)\(attribute)\n"
                }
            }
            
            // Add documentation if available
            if let documentation = decl.documentation {
                let hasParameters = !documentation.parameters.isEmpty
                let hasReturns = documentation.returns != nil
                let hasThrows = documentation.throwsInfo != nil
                let hasDescription = !documentation.description.isEmpty
                
                // Determine if we need block comment format
                let needsBlockFormat = hasParameters || hasReturns || hasThrows
                
                if hasDescription {
                    let descriptionLines = documentation.description.components(separatedBy: .newlines)
                    let nonEmptyLines = descriptionLines.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                    
                    // Use /** */ format for multi-line descriptions OR when there are parameters/returns/throws
                    let isMultiLine = nonEmptyLines.count > 1
                    let useBlockFormat = needsBlockFormat || isMultiLine
                    
                    if useBlockFormat {
                        // Use /** */ format for complex documentation or multi-line descriptions
                        interface += "\(indent)/**\n"
                        for line in nonEmptyLines {
                            interface += "\(indent) \(line.trimmingCharacters(in: .whitespacesAndNewlines))\n"
                        }
                        
                        // Add blank line before parameters/returns/throws if there's a description and parameters exist
                        if hasDescription && (hasParameters || hasReturns || hasThrows) {
                            interface += "\(indent)\n"
                        }
                        
                        // Add parameter documentation
                        if hasParameters {
                            interface += "\(indent) - Parameters:\n"
                            for (paramName, paramDesc) in documentation.parameters.sorted(by: { $0.key < $1.key }) {
                                interface += "\(indent)     - \(paramName): \(paramDesc)\n"
                            }
                        }
                        
                        // Add throws documentation
                        if let throwsInfo = documentation.throwsInfo {
                            interface += "\(indent) - Throws: \(throwsInfo)\n"
                        }
                        
                        // Add returns documentation
                        if let returns = documentation.returns {
                            interface += "\(indent) - Returns: \(returns)\n"
                        }
                        
                        interface += "\(indent) */\n"
                    } else {
                        // Use /// format for single-line simple descriptions
                        interface += "\(indent)/// \(nonEmptyLines[0].trimmingCharacters(in: .whitespacesAndNewlines))\n"
                    }
                } else if needsBlockFormat {
                    // Only parameters/returns/throws without description
                    interface += "\(indent)/**\n"
                    
                    // Add parameter documentation
                    if hasParameters {
                        interface += "\(indent) - Parameters:\n"
                        for (paramName, paramDesc) in documentation.parameters.sorted(by: { $0.key < $1.key }) {
                            interface += "\(indent)     - \(paramName): \(paramDesc)\n"
                        }
                    }
                    
                    // Add throws documentation
                    if let throwsInfo = documentation.throwsInfo {
                        interface += "\(indent) - Throws: \(throwsInfo)\n"
                    }
                    
                    // Add returns documentation
                    if let returns = documentation.returns {
                        interface += "\(indent) - Returns: \(returns)\n"
                    }
                    
                    interface += "\(indent) */\n"
                }
            }
            
            // Generate the declaration signature
            var declarationLine = "\(indent)\(decl.visibility) "
            
            if let signature = decl.signature {
                // Handle property formatting for let/var declarations
                if decl.type == "let" || decl.type == "var" {
                    // Convert let/var signatures to interface-style property declarations
                    var modifiedSignature = signature
                    
                    // Replace "let" with "var" and add "{ get }"
                    if decl.type == "let" {
                        modifiedSignature = modifiedSignature.replacingOccurrences(of: "^let ", with: "var ", options: .regularExpression)
                        modifiedSignature += " { get }"
                    }
                    // For "var", add "{ get set }"
                    else if decl.type == "var" {
                        modifiedSignature += " { get set }"
                    }
                    
                    declarationLine += modifiedSignature
                } else {
                    declarationLine += signature
                }
            } else {
                // For container types without signatures
                declarationLine += "\(decl.type) \(decl.name)"
                
                // Add inheritance/conformances if this is an extension
                if decl.type == "extension" {
                    // Extension names already include the type being extended
                    declarationLine = "\(indent)\(decl.visibility) extension \(decl.name)"
                }
            }
            
            // Add opening brace for container types
            let isContainerType = ["class", "struct", "enum", "protocol", "extension"].contains(decl.type)
            
            if isContainerType && decl.members != nil && !decl.members!.isEmpty {
                declarationLine += " {"
            }
            
            interface += "\(declarationLine)\n"
            
            // Add members for container types with proper indentation
            if let members = decl.members, !members.isEmpty {
                // Special handling for enums to group cases separately
                if decl.type == "enum" {
                    let cases = members.filter { $0.type == "case" }
                    let nonCases = members.filter { $0.type != "case" }
                    
                    // Add cases section
                    if !cases.isEmpty {
                        interface += "\n\(indent)   // Cases\n"
                        for member in cases {
                            interface += "\n"
                            addDeclaration(member, indentLevel: indentLevel + 1)
                        }
                    }
                    
                    // Add utilities section for non-case members
                    if !nonCases.isEmpty {
                        interface += "\n\n\(indent)   // Utilities\n"
                        for member in nonCases {
                            interface += "\n"
                            addDeclaration(member, indentLevel: indentLevel + 1)
                        }
                    }
                } else {
                    // Normal handling for non-enum types
                    for member in members {
                        interface += "\n"
                        addDeclaration(member, indentLevel: indentLevel + 1)
                    }
                }
                
                // Add closing brace for container types without extra space
                if isContainerType {
                    interface += "\n\(indent)}\n"
                }
            } else if isContainerType {
                // Empty container, still need closing brace
                interface += "\(indent)}\n"
            }
        }
        
        for (index, decl) in overviews.enumerated() {
            addDeclaration(decl)
            if index < overviews.count - 1 {
                interface += "\n"
            }
        }
        
        return interface
    }
    
    private func generateMarkdownOutput(_ codeOverview: CodeOverview) -> String {
        var markdown = "# Code Overview\n\n"
        
        // Add imports section if there are any imports
        if !codeOverview.imports.isEmpty {
            markdown += "## Imports\n\n"
            for importName in codeOverview.imports {
                markdown += "- `import \(importName)`\n"
            }
            markdown += "\n---\n\n"
        }
        
        func addDeclaration(_ decl: DeclarationOverview, level: Int = 2) {
            let heading = String(repeating: "#", count: level)
            let title = decl.fullName ?? decl.name
            markdown += "\(heading) \(decl.type.capitalized): \(title)\n\n"
            
            markdown += "**Path:** `\(decl.path)`  \n"
            markdown += "**Visibility:** `\(decl.visibility)`  \n"
            
            if let attributes = decl.attributes, !attributes.isEmpty {
                markdown += "**Attributes:** `\(attributes.joined(separator: " "))`  \n"
            }
            
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
                
                if let throwsInfo = documentation.throwsInfo {
                    markdown += "**Throws:** \(throwsInfo)\n\n"
                }
                
                if let returns = documentation.returns {
                    markdown += "**Returns:** \(returns)\n\n"
                }
            }
            
            // Enhanced children references with type and name information
            if let members = decl.members, !members.isEmpty {
                markdown += "**Children:**\n"
                for member in members {
                    let memberTitle = member.fullName ?? member.name
                    markdown += "- `\(member.path)` - \(member.type.capitalized): **\(memberTitle)**\n"
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
        
        processDeclarations(codeOverview.declarations)
        return markdown
    }
} 
