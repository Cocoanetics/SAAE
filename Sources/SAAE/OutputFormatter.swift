import Foundation

/// Formats declaration overviews into different output formats
internal struct OutputFormatter {
    /// Formats the code overview as a Swift interface
    internal static func formatAsInterface(_ overview: CodeOverview) -> String {
        var output: [String] = []
        
        // Add imports
        if !overview.imports.isEmpty {
            for importStmt in overview.imports {
                output.append("import \(importStmt)")
            }
            output.append("") // Empty line after imports
        }
        
        // Add declarations
        for declaration in overview.declarations {
            output.append(formatDeclarationAsInterface(declaration))
            output.append("") // Empty line between declarations
        }
        
        return output.joined(separator: "\n")
    }
    
    /// Formats the code overview as Markdown
    internal static func formatAsMarkdown(_ overview: CodeOverview) -> String {
        var output: [String] = []
        
        output.append("# Code Overview")
        output.append("")
        
        // Add imports section
        if !overview.imports.isEmpty {
            output.append("## Imports")
            output.append("")
            for importStmt in overview.imports {
                output.append("- `\(importStmt)`")
            }
            output.append("")
        }
        
        // Add declarations section
        output.append("## Declarations")
        output.append("")
        
        for declaration in overview.declarations {
            output.append(formatDeclarationAsMarkdown(declaration))
            output.append("")
        }
        
        return output.joined(separator: "\n")
    }
    
    private static func formatDeclarationAsInterface(_ declaration: DeclarationOverview, indentLevel: Int = 0) -> String {
        let indent = String(repeating: "    ", count: indentLevel)
        var lines: [String] = []
        
        // Add attributes if present
        if let attributes = declaration.attributes {
            for attribute in attributes {
                lines.append("\(indent)\(attribute)")
            }
        }
        
        // Build declaration line
        var declarationLine = "\(indent)\(declaration.visibility)"
        
        // Add modifiers if present
        if let modifiers = declaration.modifiers, !modifiers.isEmpty {
            declarationLine += " \(modifiers.joined(separator: " "))"
        }
        
        if let signature = declaration.signature {
            // For properties and methods, we might want to show the signature differently
            if declaration.type == "var" || declaration.type == "let" {
                // For properties, extract the type part and show properly
                if signature.contains(": ") {
                    let parts = signature.components(separatedBy: ": ")
                    if parts.count >= 2 {
                        let varPart = parts[0] // e.g., "let staticProperty"
                        let typePart = parts[1] // e.g., "String"
                        // Extract just the property name from the var part
                        let namePart = varPart.components(separatedBy: " ").last ?? declaration.name
                        declarationLine += " \(declaration.type) \(namePart): \(typePart)"
                    } else {
                        declarationLine += " \(signature)"
                    }
                } else {
                    declarationLine += " \(signature)"
                }
            } else {
                declarationLine += " \(signature)"
            }
        } else {
            declarationLine += " \(declaration.type) \(declaration.name)"
        }
        
        lines.append(declarationLine)
        
        // Add members if present
        if let members = declaration.members, !members.isEmpty {
            lines.append("\(indent){")
            for member in members {
                lines.append(formatDeclarationAsInterface(member, indentLevel: indentLevel + 1))
            }
            lines.append("\(indent)}")
        }
        
        return lines.joined(separator: "\n")
    }
    
    private static func formatDeclarationAsMarkdown(_ declaration: DeclarationOverview, level: Int = 3) -> String {
        var output: [String] = []
        
        let headerPrefix = String(repeating: "#", count: level)
        output.append("\(headerPrefix) \(declaration.name)")
        output.append("")
        
        // Basic information
        output.append("**Type:** `\(declaration.type)`")
        output.append("**Visibility:** `\(declaration.visibility)`")
        output.append("**Path:** `\(declaration.path)`")
        if let fullName = declaration.fullName {
            output.append("**Full Name:** `\(fullName)`")
        }
        
        // Modifiers
        if let modifiers = declaration.modifiers, !modifiers.isEmpty {
            output.append("**Modifiers:** `\(modifiers.joined(separator: ", "))`")
        }
        
        // Attributes
        if let attributes = declaration.attributes, !attributes.isEmpty {
            output.append("**Attributes:**")
            for attribute in attributes {
                output.append("- `\(attribute)`")
            }
        }
        
        // Signature
        if let signature = declaration.signature {
            output.append("**Signature:**")
            output.append("```swift")
            output.append(signature)
            output.append("```")
        }
        
        // Documentation
        if let documentation = declaration.documentation {
            output.append("**Documentation:**")
            output.append("")
            if !documentation.description.isEmpty {
                output.append(documentation.description)
                output.append("")
            }
            if let returns = documentation.returns {
                output.append("**Returns:** \(returns)")
                output.append("")
            }
            if let throwsInfo = documentation.throwsInfo {
                output.append("**Throws:** \(throwsInfo)")
                output.append("")
            }
            if !documentation.parameters.isEmpty {
                output.append("**Parameters:**")
                for (param, desc) in documentation.parameters {
                    output.append("- **\(param):** \(desc)")
                }
                output.append("")
            }
        }
        
        // Members
        if let members = declaration.members, !members.isEmpty {
            output.append("**Members:**")
            output.append("")
            for member in members {
                output.append(formatDeclarationAsMarkdown(member, level: level + 1))
                output.append("")
            }
        }
        
        return output.joined(separator: "\n")
    }
} 