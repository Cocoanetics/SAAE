import Foundation
import Yams

/// Provides comprehensive analysis of multiple Swift files as a cohesive project.
///
/// `ProjectOverview` coordinates the analysis of multiple Swift source files,
/// organizing their individual overviews into a unified project-level view.
/// It handles the complexity of multi-file relationships and provides
/// consolidated output in various formats.
///
/// ## Usage
///
/// ```swift
/// let projectOverview = ProjectOverview(
///     fileURLs: [file1URL, file2URL, file3URL],
///     minVisibility: .public
/// )
/// let markdownDoc = try projectOverview.generateOverview(format: .markdown)
/// ```
///
/// ## Output Formats
///
/// - **JSON/YAML**: Structured data with file metadata and cross-references
/// - **Markdown**: Comprehensive documentation with file navigation
/// - **Interface**: Concatenated interface declarations with file separators
public struct ProjectOverview {
    
    /// Individual file analysis results.
    private let fileOverviews: [FileOverview]
    
    /// The minimum visibility level applied across all files.
    private let minVisibility: VisibilityLevel
    
    /// Creates a project overview by analyzing multiple Swift files.
    ///
    /// This initializer processes each file URL, performs individual analysis,
    /// and organizes the results for project-level consumption.
    ///
    /// - Parameters:
    ///   - fileURLs: Array of file URLs pointing to Swift source files to analyze.
    ///   - minVisibility: The minimum visibility level to include in the analysis.
    ///
    /// - Throws:
    ///   - ``SAAEError/fileNotFound(_:)`` if any specified file doesn't exist.
    ///   - ``SAAEError/fileReadError(_:_:)`` if any file cannot be read.
    public init(fileURLs: [URL], minVisibility: VisibilityLevel = .internal) throws {
        self.minVisibility = minVisibility
        var results: [FileOverview] = []
        
        for url in fileURLs {
            let tree = try SyntaxTree(url: url)
            let overview = CodeOverview(tree: tree, minVisibility: minVisibility)
            
            let fileOverview = FileOverview(
                path: url.path,
                imports: overview.imports,
                declarations: overview.declarations
            )
            results.append(fileOverview)
        }
        
        self.fileOverviews = results
    }
    
    /// Generates a comprehensive overview of the project in the specified format.
    ///
    /// This method consolidates the individual file analyses into a unified
    /// project overview, with format-specific organization and presentation.
    ///
    /// - Parameter format: The desired output format for the project overview.
    /// - Returns: A string containing the project overview in the specified format.
    /// - Throws: Encoding errors if the output format cannot be generated.
    ///
    /// ## Format-Specific Behavior
    ///
    /// - **JSON/YAML**: Creates a structured object with file metadata and declarations
    /// - **Markdown**: Generates a comprehensive document with file sections and navigation
    /// - **Interface**: Concatenates interface declarations with clear file separators
    public func generateOverview(format: OutputFormat) throws -> String {
        switch format {
        case .json:
            let multiFileOverview = MultiFileCodeOverview(files: fileOverviews)
            return try generateJSONOutput(multiFileOverview)
        case .yaml:
            let multiFileOverview = MultiFileCodeOverview(files: fileOverviews)
            return try generateYAMLOutput(multiFileOverview)
        case .markdown:
            return generateMarkdownOutput()
        case .interface:
            return generateInterfaceOutput()
        }
    }
    
    /// The file system paths of all analyzed files.
    ///
    /// Provides access to the paths of all files included in this project overview,
    /// useful for debugging and reporting purposes.
    public var filePaths: [String] {
        return fileOverviews.map { $0.path }
    }
    
    /// The total number of declarations across all files.
    ///
    /// Provides a quick metric of the project size in terms of analyzed declarations.
    public var totalDeclarationCount: Int {
        return fileOverviews.reduce(0) { $0 + $1.declarations.count }
    }
    
    /// All unique import statements across the project.
    ///
    /// Consolidates imports from all files, providing a view of the project's
    /// external dependencies.
    public var allImports: [String] {
        let allImports = fileOverviews.flatMap { $0.imports }
        return Array(Set(allImports)).sorted()
    }
}

// MARK: - Private Output Generation Methods

extension ProjectOverview {
    
    /// Generates JSON output for the project overview.
    ///
    /// - Parameter multiFileOverview: The structured multi-file overview to encode.
    /// - Returns: A pretty-printed JSON string representation.
    /// - Throws: Encoding errors if JSON generation fails.
    private func generateJSONOutput(_ multiFileOverview: MultiFileCodeOverview) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(multiFileOverview)
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    /// Generates YAML output for the project overview.
    ///
    /// - Parameter multiFileOverview: The structured multi-file overview to encode.
    /// - Returns: A YAML string representation.
    /// - Throws: Encoding errors if YAML generation fails.
    private func generateYAMLOutput(_ multiFileOverview: MultiFileCodeOverview) throws -> String {
        let encoder = YAMLEncoder()
        return try encoder.encode(multiFileOverview)
    }
    
    /// Generates Markdown documentation for the project.
    ///
    /// Creates a comprehensive Markdown document with file navigation,
    /// detailed declaration information, and cross-references between files.
    ///
    /// - Returns: A formatted Markdown string.
    private func generateMarkdownOutput() -> String {
        var markdown = "# Project Overview\n\n"
        
        // Add project summary
        markdown += "## Project Summary\n\n"
        markdown += "- **Files Analyzed**: \(fileOverviews.count)\n"
        markdown += "- **Total Declarations**: \(totalDeclarationCount)\n"
        markdown += "- **Unique Imports**: \(allImports.count)\n\n"
        
        // Add overview of all files
        markdown += "## Files\n\n"
        for (index, fileOverview) in fileOverviews.enumerated() {
            markdown += "\(index + 1). [`\(fileOverview.path)`](#file-\(index + 1))\n"
        }
        markdown += "\n---\n\n"
        
        // Add detailed analysis for each file
        for (index, fileOverview) in fileOverviews.enumerated() {
            markdown += "## File \(index + 1): `\(fileOverview.path)`\n\n"
            
            // Add imports if any
            if !fileOverview.imports.isEmpty {
                markdown += "### Imports\n\n"
                for importName in fileOverview.imports {
                    markdown += "- `import \(importName)`\n"
                }
                markdown += "\n"
            }
            
            // Add declarations
            if !fileOverview.declarations.isEmpty {
                markdown += "### Declarations\n\n"
                
                func addDeclaration(_ decl: DeclarationOverview, level: Int = 4) {
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
                
                processDeclarations(fileOverview.declarations)
            }
            
            if index < fileOverviews.count - 1 {
                markdown += "\n" + String(repeating: "=", count: 80) + "\n\n"
            }
        }
        
        return markdown
    }
    
    /// Generates Swift interface declarations for the project.
    ///
    /// Creates clean interface-style declarations showing the public API
    /// of all files, with proper file separation and formatting.
    ///
    /// - Returns: A formatted Swift interface string with file separators.
    private func generateInterfaceOutput() -> String {
        var interface = ""
        
        for (index, fileOverview) in fileOverviews.enumerated() {
            interface += "// File: \(fileOverview.path)\n"
            interface += String(repeating: "=", count: fileOverview.path.count + 8) + "\n\n"
            
            // Add imports
            for importName in fileOverview.imports {
                interface += "import \(importName)\n"
            }
            
            if !fileOverview.imports.isEmpty {
                interface += "\n"
            }
            
            // Generate interface for declarations
            func addDeclaration(_ decl: DeclarationOverview, indentLevel: Int = 0) {
                let indent = String(repeating: "   ", count: indentLevel)
                
                // Add attributes if present
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
                var declarationLine: String
                
                if decl.type == "case" || decl.type == "extension" {
                    declarationLine = "\(indent)"
                } else {
                    declarationLine = "\(indent)\(decl.visibility) "
                }
                
                if let signature = decl.signature {
                    if decl.type == "case" {
                        declarationLine += "case \(signature)"
                    } else if decl.type == "extension" {
                        declarationLine += "extension \(signature)"
                    } else {
                        declarationLine += signature
                    }
                } else {
                    if decl.type == "case" {
                        declarationLine += "case \(decl.name)"
                    } else if decl.type == "extension" {
                        declarationLine += "extension \(decl.name)"
                    } else {
                        declarationLine += "\(decl.type) \(decl.name)"
                    }
                }
                
                let isContainerType = ["class", "struct", "enum", "protocol", "extension"].contains(decl.type)
                
                if isContainerType && decl.members != nil && !decl.members!.isEmpty {
                    declarationLine += " {"
                }
                
                interface += "\(declarationLine)\n"
                
                if let members = decl.members, !members.isEmpty {
                    for member in members {
                        interface += "\n"
                        addDeclaration(member, indentLevel: indentLevel + 1)
                    }
                    
                    if isContainerType {
                        interface += "\n\(indent)}\n"
                    }
                } else if isContainerType {
                    interface += "\(indent)}\n"
                }
            }
            
            for (declIndex, decl) in fileOverview.declarations.enumerated() {
                addDeclaration(decl)
                if declIndex < fileOverview.declarations.count - 1 {
                    interface += "\n"
                }
            }
            
            if index < fileOverviews.count - 1 {
                interface += "\n\n" + String(repeating: "-", count: 50) + "\n\n"
            }
        }
        
        return interface
    }
} 