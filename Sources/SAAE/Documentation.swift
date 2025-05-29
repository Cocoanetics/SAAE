import Foundation

/// Documentation structure for parsing Swift documentation comments
internal struct Documentation: Codable {
    internal let description: String
    internal let parameters: [String: String]
    internal let returns: String?
    internal let throwsInfo: String?
    
    internal init(from text: String) {
        var description = ""
        var parameters: [String: String] = [:]
        var returns: String?
        var throwsInfo: String?
        
        let lines = text.components(separatedBy: .newlines)
        var currentSection: String?
        var currentContent = ""
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip empty lines and comment-only lines
            if trimmedLine.isEmpty || trimmedLine == "*" || trimmedLine == "/**" || trimmedLine == "*/" {
                continue
            }
            
            // Remove common documentation comment prefixes
            var cleanLine = trimmedLine
                .replacingOccurrences(of: "^///\\s*", with: "", options: .regularExpression)
                .replacingOccurrences(of: "^\\*\\s*", with: "", options: .regularExpression)
                .replacingOccurrences(of: "^/\\*\\*\\s*", with: "", options: .regularExpression)
                .replacingOccurrences(of: "\\*/$", with: "", options: .regularExpression)
            
            // Additional cleanup for block comments - remove leading/trailing /** and */
            cleanLine = cleanLine
                .replacingOccurrences(of: "^/\\*\\*", with: "", options: .regularExpression)
                .replacingOccurrences(of: "\\*/$", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip if the line is now empty after cleaning
            if cleanLine.isEmpty {
                continue
            }
            
            if cleanLine.hasPrefix("- Parameter ") || cleanLine.hasPrefix("- parameter ") {
                // Save previous section
                if let section = currentSection {
                    switch section {
                    case "description":
                        description = currentContent.trimmingCharacters(in: .whitespacesAndNewlines)
                    case "returns":
                        returns = currentContent.trimmingCharacters(in: .whitespacesAndNewlines)
                    case "throws":
                        throwsInfo = currentContent.trimmingCharacters(in: .whitespacesAndNewlines)
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
            } else if cleanLine.hasPrefix("- Parameters:") || cleanLine.hasPrefix("- parameters:") {
                // Save previous section
                if currentSection == "description" {
                    description = currentContent.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                
                currentSection = "parameters"
                currentContent = ""
            } else if cleanLine.hasPrefix("- Returns:") || cleanLine.hasPrefix("- returns:") {
                // Save previous section
                if currentSection == "description" {
                    description = currentContent.trimmingCharacters(in: .whitespacesAndNewlines)
                } else if currentSection == "throws" {
                    throwsInfo = currentContent.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                
                currentSection = "returns"
                currentContent = cleanLine.replacingOccurrences(of: "^- [Rr]eturns:\\s*", with: "", options: .regularExpression)
            } else if cleanLine.hasPrefix("- Throws:") || cleanLine.hasPrefix("- throws:") {
                // Save previous section
                if currentSection == "description" {
                    description = currentContent.trimmingCharacters(in: .whitespacesAndNewlines)
                } else if currentSection == "returns" {
                    returns = currentContent.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                
                currentSection = "throws"
                currentContent = cleanLine.replacingOccurrences(of: "^- [Tt]hrows:\\s*", with: "", options: .regularExpression)
            } else if currentSection == "parameters" && (cleanLine.hasPrefix("- ") && cleanLine.contains(":")) {
                // Handle individual parameter entries under Parameters section
                let parameterContent = cleanLine.replacingOccurrences(of: "^-\\s+", with: "", options: .regularExpression)
                if let colonIndex = parameterContent.firstIndex(of: ":") {
                    let paramName = String(parameterContent[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                    let paramDesc = String(parameterContent[parameterContent.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                    parameters[paramName] = paramDesc
                }
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
            case "throws":
                throwsInfo = currentContent.trimmingCharacters(in: .whitespacesAndNewlines)
            case "parameters":
                // Parameters section - individual parameters should already be parsed
                break
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
        self.throwsInfo = throwsInfo?.isEmpty == true ? nil : throwsInfo
    }
} 