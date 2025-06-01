import Foundation
import Yams

/// Provides a comprehensive analysis and overview of Swift source code.
///
/// `CodeOverview` serves as the primary analysis engine for SAAE, parsing Swift syntax trees
/// and extracting structured information about declarations, imports, and documentation.
/// It supports multiple output formats and configurable visibility filtering.
///
/// ## Core Functionality
///
/// - **Declaration Analysis**: Extracts and organizes all declarations with their metadata
/// - **Import Tracking**: Identifies all module dependencies
/// - **Documentation Parsing**: Processes Swift documentation comments
/// - **Multi-Format Output**: Generates JSON, YAML, Markdown, and Interface representations
/// - **Visibility Filtering**: Respects access control levels
///
/// ## Usage
///
/// ```swift
/// let tree = try SyntaxTree(url: fileURL)
/// let overview = CodeOverview(tree: tree, minVisibility: .public)
/// 
/// // Generate different formats
/// let json = try overview.json()
/// let markdown = overview.markdown()
/// let interface = overview.interface()
/// ```
///
/// ## Output Formats
///
/// Each format serves different purposes:
/// - **JSON**: Machine-readable data for tools and APIs
/// - **YAML**: Human-readable structured data
/// - **Markdown**: Rich documentation with cross-references
/// - **Interface**: Clean Swift-like API signatures
public class CodeOverview {

/// The syntax tree being analyzed.
    internal let tree: SyntaxTree

/// The minimum visibility level for included declarations.
    internal let minVisibility: VisibilityLevel

// Lazy-computed analysis results
    internal var _imports: [String]?
    internal var _declarations: [DeclarationOverview]?

/// All declarations found in the source code, filtered by visibility level.
///
/// This array contains structured representations of all Swift declarations
/// (classes, structs, functions, etc.) that meet the minimum visibility requirement.
/// Declarations are organized hierarchically with nested types represented as children.
    public let declarations: [DeclarationOverview]

/// All import statements found in the source code.
///
/// Contains the complete module paths for all import declarations,
/// sorted alphabetically for consistent output.
    public let imports: [String]

/// Creates a code overview by analyzing the provided syntax tree.
///
/// This initializer performs the complete analysis of the source code,
/// extracting declarations, imports, and documentation. The analysis
/// respects the specified minimum visibility level.
///
/// - Parameters:
///   - tree: The parsed syntax tree to analyze.
///   - minVisibility: The minimum visibility level to include in the analysis.
///     Only declarations with this visibility level or higher will be included.
///
/// ## Analysis Process
///
/// 1. **Declaration Extraction**: Traverses the syntax tree to find all declarations
/// 2. **Visibility Filtering**: Excludes declarations below the minimum visibility
/// 3. **Import Collection**: Identifies all import statements
/// 4. **Documentation Parsing**: Extracts and structures documentation comments
/// 5. **Hierarchy Building**: Organizes nested declarations appropriately
    public init(tree: SyntaxTree, minVisibility: VisibilityLevel = .internal) {
        self.tree = tree
        self.minVisibility = minVisibility

        let visitor = DeclarationVisitor(minVisibility: minVisibility)
        visitor.walk(tree.sourceFile)
        let result = visitor.declarations
        _declarations = result
        declarations = result

        let importVisitor = ImportVisitor()
        importVisitor.walk(tree.sourceFile)
        let resultImports = importVisitor.imports.sorted()
        _imports = resultImports
        imports = resultImports
    }

/// Generates a JSON representation of the code overview.
///
/// Creates a structured JSON document containing imports and declarations
/// with comprehensive metadata for each declaration including documentation,
/// signatures, and hierarchical relationships.
///
/// - Returns: A pretty-printed JSON string.
/// - Throws: Encoding errors if JSON generation fails.
///
/// ## JSON Structure
///
/// ```json
/// {
///   "imports": ["Foundation", "SwiftUI"],
///   "declarations": [
///     {
///       "path": "1",
///       "type": "class",
///       "name": "MyClass",
///       "visibility": "public",
///       "signature": "class MyClass: BaseClass",
///       "members": [...]
///     }
///   ]
/// }
/// ```
    public func json() throws -> String {
        struct CodeOverviewData: Codable {
            let imports: [String]
            let declarations: [DeclarationOverview]
        }

        let overview = CodeOverviewData(imports: imports, declarations: declarations)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(overview)
        return String(data: data, encoding: .utf8) ?? ""
    }

/// Generates a YAML representation of the code overview.
///
/// Creates a human-readable YAML document with the same structure as JSON
/// but formatted for easier reading and editing.
///
/// - Returns: A formatted YAML string.
/// - Throws: Encoding errors if YAML generation fails.
///
/// ## YAML Structure
///
/// ```yaml
/// imports:
///   - Foundation
///   - SwiftUI
/// declarations:
///   - name: MyClass
///     type: class
///     visibility: public
///     members: [...]
/// ```
    public func yaml() throws -> String {
        struct CodeOverviewData: Codable {
            let imports: [String]
            let declarations: [DeclarationOverview]
        }

        let overview = CodeOverviewData(imports: imports, declarations: declarations)
        let encoder = YAMLEncoder()
        return try encoder.encode(overview)
    }

/// Generates a Markdown documentation representation of the code overview.
///
/// Creates comprehensive documentation with sections for imports and declarations,
/// including formatted documentation comments, parameter lists, and hierarchical
/// organization of nested types.
///
/// - Returns: A formatted Markdown string suitable for documentation sites.
///
/// ## Markdown Features
///
/// - **Hierarchical Headings**: Organized by declaration type and nesting level
/// - **Code Blocks**: Syntax-highlighted signatures and examples
/// - **Cross-References**: Links between related declarations
/// - **Metadata Tables**: Visibility, attributes, and other properties
/// - **Documentation**: Formatted parameter lists and descriptions
    public func markdown() -> String {
        var markdown = "# Code Overview\n\n"

// Add imports section if there are any imports
        if !imports.isEmpty {
            markdown += "## Imports\n\n"
            for importName in imports {
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

        processDeclarations(declarations)
        return markdown
    }

/// Generates a Swift interface representation of the code overview.
///
/// Creates clean, Swift-like interface declarations that show the public API
/// without implementation details. This format is ideal for understanding
/// the structure and contracts of Swift code.
///
/// - Returns: A formatted Swift interface string with proper indentation and syntax.
///
/// ## Interface Features
///
/// - **Clean Signatures**: Method and property declarations without implementation
/// - **Proper Formatting**: Correct indentation and Swift syntax
/// - **Documentation Comments**: Preserved documentation in appropriate format
/// - **Hierarchical Structure**: Nested types properly indented
/// - **Visibility Modifiers**: All access control levels preserved
/// - **Attributes**: Property wrappers and other attributes included
///
/// ## Example Output
///
/// ```swift
/// import Foundation
/// 
/// /// A sample class demonstrating interface generation
/// public class Calculator {
///     /// Adds two numbers together
///     /// - Parameters:
///     ///   - a: First number
///     ///   - b: Second number
///     /// - Returns: Sum of the two numbers
///     public func add(_ a: Int, _ b: Int) -> Int
/// }
/// ```
    public func interface() -> String {
        var interface = ""

// Add imports at the top
        for importName in imports {
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
// Don't filter out empty lines to preserve paragraph breaks
                    let allLines = descriptionLines

// Use /** */ format for multi-line descriptions OR when there are parameters/returns/throws
                    let isMultiLine = allLines.count > 1
                    let useBlockFormat = needsBlockFormat || isMultiLine

                    if useBlockFormat {
// Use /** */ format for complex documentation or multi-line descriptions
                        interface += "\(indent)/**\n"
                        for line in allLines {
                            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                            if trimmedLine.isEmpty {
// Preserve empty lines as paragraph breaks
                                interface += "\(indent)\n"
                            } else {
                                interface += "\(indent) \(trimmedLine)\n"
                            }
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
                        let firstNonEmptyLine = allLines.first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                        if let line = firstNonEmptyLine {
                            interface += "\(indent)/// \(line.trimmingCharacters(in: .whitespacesAndNewlines))\n"
                        }
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

// Enum cases and extensions don't show their visibility
            if decl.type == "case" || decl.type == "extension" {
                declarationLine = "\(indent)"
            } else {
                declarationLine = "\(indent)\(decl.visibility) "
            }

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
                } else if decl.type == "case" {
// For enum cases, show "case" keyword but omit visibility modifier
                        declarationLine += "case \(signature)"
                    } else if decl.type == "extension" {
// For extensions, use the signature which includes protocol conformances
                            declarationLine += "extension \(signature)"
                        } else {
                            declarationLine += signature
                        }
            } else {
// For container types without signatures
                if decl.type == "case" {
                    declarationLine += "case \(decl.name)"
                } else if decl.type == "extension" {
// Extensions show without visibility modifier
                        declarationLine += "extension \(decl.name)"
                    } else {
                        declarationLine += "\(decl.type) \(decl.name)"
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

        for (index, decl) in declarations.enumerated() {
            addDeclaration(decl)
            if index < declarations.count - 1 {
                interface += "\n"
            }
        }

        return interface
    }
}
