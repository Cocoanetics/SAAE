import Foundation

/// Output format for the overview generation
public enum OutputFormat {
    case json
    case yaml
    case markdown
}

/// Visibility levels for Swift declarations
public enum VisibilityLevel: Int, CaseIterable, Comparable {
    case `private` = 0
    case `fileprivate` = 1
    case `internal` = 2
    case `package` = 3
    case `public` = 4
    case `open` = 5
    
    public static func < (lhs: VisibilityLevel, rhs: VisibilityLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
    
    public var stringValue: String {
        switch self {
        case .private: return "private"
        case .fileprivate: return "fileprivate"
        case .internal: return "internal"
        case .package: return "package"
        case .public: return "public"
        case .open: return "open"
        }
    }
}

/// Opaque handle for a parsed AST
public struct ASTHandle {
    internal let id: UUID
    
    internal init() {
        self.id = UUID()
    }
}

/// Documentation structure for parsing Swift documentation comments
public struct Documentation: Codable {
    public let description: String
    public let parameters: [String: String]
    public let returns: String?
    
    public init(from text: String) {
        var description = ""
        var parameters: [String: String] = [:]
        var returns: String?
        
        let lines = text.components(separatedBy: .newlines)
        var currentSection: String?
        var currentContent = ""
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Remove common documentation comment prefixes
            let cleanLine = trimmedLine
                .replacingOccurrences(of: "^///\\s*", with: "", options: .regularExpression)
                .replacingOccurrences(of: "^\\*\\s*", with: "", options: .regularExpression)
                .replacingOccurrences(of: "^/\\*\\*\\s*", with: "", options: .regularExpression)
                .replacingOccurrences(of: "\\*/$", with: "", options: .regularExpression)
            
            if cleanLine.hasPrefix("- Parameter ") || cleanLine.hasPrefix("- parameter ") {
                // Save previous section
                if let section = currentSection {
                    switch section {
                    case "description":
                        description = currentContent.trimmingCharacters(in: .whitespacesAndNewlines)
                    case "returns":
                        returns = currentContent.trimmingCharacters(in: .whitespacesAndNewlines)
                    default:
                        if section.hasPrefix("parameter:") {
                            let paramName = String(section.dropFirst("parameter:".count))
                            parameters[paramName] = currentContent.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    }
                }
                
                // Parse parameter
                let parameterContent = cleanLine.replacingOccurrences(of: "^- [Pp]arameter\\s+", with: "", options: .regularExpression)
                if let colonIndex = parameterContent.firstIndex(of: ":") {
                    let paramName = String(parameterContent[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                    let paramDesc = String(parameterContent[parameterContent.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                    parameters[paramName] = paramDesc
                }
                currentSection = nil
                currentContent = ""
            } else if cleanLine.hasPrefix("- Returns:") || cleanLine.hasPrefix("- returns:") {
                // Save previous section
                if currentSection == "description" {
                    description = currentContent.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                
                currentSection = "returns"
                currentContent = cleanLine.replacingOccurrences(of: "^- [Rr]eturns:\\s*", with: "", options: .regularExpression)
            } else if !cleanLine.isEmpty {
                if currentSection == nil {
                    currentSection = "description"
                }
                
                if !currentContent.isEmpty {
                    currentContent += "\n"
                }
                currentContent += cleanLine
            }
        }
        
        // Save final section
        if let section = currentSection {
            switch section {
            case "description":
                description = currentContent.trimmingCharacters(in: .whitespacesAndNewlines)
            case "returns":
                returns = currentContent.trimmingCharacters(in: .whitespacesAndNewlines)
            default:
                if section.hasPrefix("parameter:") {
                    let paramName = String(section.dropFirst("parameter:".count))
                    parameters[paramName] = currentContent.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        
        self.description = description
        self.parameters = parameters
        self.returns = returns?.isEmpty == true ? nil : returns
    }
}

/// Represents a declaration in the overview
public struct DeclarationOverview: Codable {
    public let path: String
    public let type: String
    public let name: String
    public let fullName: String?
    public let signature: String?
    public let visibility: String
    public let documentation: Documentation?
    public let members: [DeclarationOverview]?
    public let childPaths: [String]?
    
    public init(
        path: String,
        type: String,
        name: String,
        fullName: String? = nil,
        signature: String? = nil,
        visibility: String,
        documentation: Documentation? = nil,
        members: [DeclarationOverview]? = nil,
        childPaths: [String]? = nil
    ) {
        self.path = path
        self.type = type
        self.name = name
        self.fullName = fullName
        self.signature = signature
        self.visibility = visibility
        self.documentation = documentation
        self.members = members
        self.childPaths = childPaths
    }
} 