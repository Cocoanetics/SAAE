import Foundation
import SwiftSyntax
import SwiftParser
import Yams

/// The main SAAE (Swift AST Abstractor & Editor) class for analyzing Swift source code.
///
/// SAAE provides a comprehensive interface for parsing Swift source files and generating
/// structured overviews in multiple formats. It abstracts the complexity of SwiftSyntax
/// and provides convenient methods for common code analysis tasks.
///
/// ## Overview
///
/// The SAAE class supports:
/// - Single-file analysis from URLs or strings
/// - Multi-file analysis for entire projects
/// - Multiple output formats (JSON, YAML, Markdown, Interface)
/// - Configurable visibility filtering
/// - Comprehensive error handling
///
/// ## Basic Usage
///
/// ```swift
/// let saae = SAAE()
/// 
/// // Analyze a single file
/// let overview = try saae.generateOverview(
///     url: fileURL,
///     format: .markdown,
///     minVisibility: .public
/// )
/// 
/// // Analyze multiple files
/// let multiFileOverview = try saae.generateMultiFileOverview(
///     urls: [file1URL, file2URL],
///     format: .json,
///     minVisibility: .internal
/// )
/// ```
///
/// ## Output Formats
///
/// - **JSON**: Structured data for programmatic consumption
/// - **YAML**: Human-readable structured data
/// - **Markdown**: Documentation-friendly format
/// - **Interface**: Swift-like interface declarations
public class SAAE {
    
    /// Creates a new SAAE instance.
    ///
    /// The initializer sets up the SAAE instance ready for code analysis.
    /// No additional configuration is required after initialization.
    public init() {}
    
    /// Analyzes Swift code from a file and generates an overview in the specified format.
    ///
    /// This method reads and parses a Swift source file, analyzes its declarations,
    /// and generates a formatted overview based on the specified parameters.
    ///
    /// - Parameters:
    ///   - url: A file URL pointing to a local Swift source file to analyze.
    ///   - format: The desired output format for the generated overview.
    ///   - minVisibility: The minimum visibility level to include in the analysis.
    ///     Only declarations with this visibility level or higher will be included.
    ///
    /// - Returns: A string containing the generated overview in the specified format.
    ///
    /// - Throws:
    ///   - ``SAAEError/fileNotFound(_:)`` if the specified file doesn't exist.
    ///   - ``SAAEError/fileReadError(_:_:)`` if the file cannot be read.
    ///   - Encoding errors if the output format cannot be generated.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let saae = SAAE()
    /// let fileURL = URL(fileURLWithPath: "MyClass.swift")
    /// let overview = try saae.generateOverview(
    ///     url: fileURL,
    ///     format: .markdown,
    ///     minVisibility: .public
    /// )
    /// print(overview)
    /// ```
    public func generateOverview(
        url: URL,
        format: OutputFormat = .json,
        minVisibility: VisibilityLevel = .internal
    ) throws -> String {
        let tree = try SyntaxTree(url: url)
        let overview = CodeOverview(tree: tree, minVisibility: minVisibility)
        
        switch format {
        case .json:
            return try overview.json()
        case .yaml:
            return try overview.yaml()
        case .markdown:
            return overview.markdown()
        case .interface:
            return overview.interface()
        }
    }
    
    /// Analyzes Swift code from a string and generates an overview in the specified format.
    ///
    /// This method parses Swift source code provided as a string, analyzes its declarations,
    /// and generates a formatted overview. This is useful for analyzing dynamically generated
    /// code or code snippets.
    ///
    /// - Parameters:
    ///   - string: A string containing valid Swift source code to analyze.
    ///   - format: The desired output format for the generated overview.
    ///   - minVisibility: The minimum visibility level to include in the analysis.
    ///     Only declarations with this visibility level or higher will be included.
    ///
    /// - Returns: A string containing the generated overview in the specified format.
    ///
    /// - Throws: Encoding errors if the output format cannot be generated.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let sourceCode = """
    /// public class Calculator {
    ///     public func add(_ a: Int, _ b: Int) -> Int {
    ///         return a + b
    ///     }
    /// }
    /// """
    /// 
    /// let saae = SAAE()
    /// let overview = try saae.generateOverview(
    ///     string: sourceCode,
    ///     format: .interface,
    ///     minVisibility: .public
    /// )
    /// ```
    public func generateOverview(
        string: String,
        format: OutputFormat = .json,
        minVisibility: VisibilityLevel = .internal
    ) throws -> String {
        let tree = try SyntaxTree(string: string)
        let overview = CodeOverview(tree: tree, minVisibility: minVisibility)
        
        switch format {
        case .json:
            return try overview.json()
        case .yaml:
            return try overview.yaml()
        case .markdown:
            return overview.markdown()
        case .interface:
            return overview.interface()
        }
    }
    
    /// Generates a comprehensive overview of multiple Swift files.
    ///
    /// This method analyzes multiple Swift source files and combines their declarations
    /// into a unified overview. The output format determines how the multi-file information
    /// is structured and presented.
    ///
    /// - Parameters:
    ///   - urls: An array of file URLs pointing to Swift source files to analyze.
    ///   - format: The desired output format for the generated overview.
    ///   - minVisibility: The minimum visibility level to include in the analysis.
    ///     Only declarations with this visibility level or higher will be included.
    ///
    /// - Returns: A string containing the multi-file overview in the specified format.
    ///
    /// - Throws:
    ///   - ``SAAEError/fileNotFound(_:)`` if any specified file doesn't exist.
    ///   - ``SAAEError/fileReadError(_:_:)`` if any file cannot be read.
    ///   - Encoding errors if the output format cannot be generated.
    ///
    /// ## Format-Specific Behavior
    ///
    /// - **JSON/YAML**: Creates a structured object with file metadata and declarations.
    /// - **Markdown**: Generates a comprehensive document with file sections and cross-references.
    /// - **Interface**: Concatenates interface declarations with file separators.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let saae = SAAE()
    /// let fileURLs = [
    ///     URL(fileURLWithPath: "Models.swift"),
    ///     URL(fileURLWithPath: "ViewControllers.swift")
    /// ]
    /// 
    /// let overview = try saae.generateMultiFileOverview(
    ///     urls: fileURLs,
    ///     format: .markdown,
    ///     minVisibility: .public
    /// )
    /// ```
    public func generateMultiFileOverview(
        urls: [URL],
        format: OutputFormat = .json,
        minVisibility: VisibilityLevel = .internal
    ) throws -> String {
        var fileOverviews: [FileOverview] = []
        
        for url in urls {
            let tree = try SyntaxTree(url: url)
            let overview = CodeOverview(tree: tree, minVisibility: minVisibility)
            
            let fileOverview = FileOverview(
                path: url.path,
                imports: overview.imports,
                declarations: overview.declarations
            )
            fileOverviews.append(fileOverview)
        }
        
        switch format {
        case .json:
            let multiFileOverview = MultiFileCodeOverview(files: fileOverviews)
            return try generateMultiFileJSONOutput(multiFileOverview)
        case .yaml:
            let multiFileOverview = MultiFileCodeOverview(files: fileOverviews)
            return try generateMultiFileYAMLOutput(multiFileOverview)
        case .markdown:
            return generateMultiFileMarkdownOutput(fileOverviews)
        case .interface:
            return generateMultiFileInterfaceOutput(fileOverviews)
        }
    }
    
    // MARK: - Private Multi-File Output Generation Methods
    
    /// Generates JSON output for multi-file code overview.
    ///
    /// - Parameter multiFileOverview: The structured multi-file overview to encode.
    /// - Returns: A pretty-printed JSON string representation.
    /// - Throws: Encoding errors if JSON generation fails.
    private func generateMultiFileJSONOutput(_ multiFileOverview: MultiFileCodeOverview) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(multiFileOverview)
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    /// Generates YAML output for multi-file code overview.
    ///
    /// - Parameter multiFileOverview: The structured multi-file overview to encode.
    /// - Returns: A YAML string representation.
    /// - Throws: Encoding errors if YAML generation fails.
    private func generateMultiFileYAMLOutput(_ multiFileOverview: MultiFileCodeOverview) throws -> String {
        let encoder = YAMLEncoder()
        return try encoder.encode(multiFileOverview)
    }
    
    /// Generates Markdown documentation for multiple Swift files.
    ///
    /// Creates a comprehensive Markdown document with file navigation,
    /// detailed declaration information, and cross-references between files.
    ///
    /// - Parameter fileOverviews: Array of file overviews to document.
    /// - Returns: A formatted Markdown string.
    private func generateMultiFileMarkdownOutput(_ fileOverviews: [FileOverview]) -> String {
        var markdown = "# Multi-File Code Overview\n\n"
        
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
    
    /// Generates Swift interface declarations for multiple files.
    ///
    /// Creates clean interface-style declarations showing the public API
    /// of multiple Swift files, with proper file separation and formatting.
    ///
    /// - Parameter fileOverviews: Array of file overviews to generate interfaces for.
    /// - Returns: A formatted Swift interface string with file separators.
    private func generateMultiFileInterfaceOutput(_ fileOverviews: [FileOverview]) -> String {
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
                
                // Generate the declaration signature
                var declarationLine: String
                
                if decl.type == "case" {
                    declarationLine = "\(indent)"
                } else {
                    declarationLine = "\(indent)\(decl.visibility) "
                }
                
                if let signature = decl.signature {
                    if decl.type == "case" {
                        declarationLine += "case \(signature)"
                    } else {
                        declarationLine += signature
                    }
                } else {
                    if decl.type == "case" {
                        declarationLine += "case \(decl.name)"
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
