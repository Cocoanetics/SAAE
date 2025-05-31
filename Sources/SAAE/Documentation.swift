import Foundation

/// Represents parsed Swift documentation comments with structured information.
///
/// This structure parses and organizes Swift documentation comments (both `///` and `/** */` styles)
/// into separate components for easier consumption and formatting. It extracts descriptions,
/// parameter documentation, return value information, and throws clauses.
///
/// ## Supported Documentation Formats
///
/// The parser supports standard Swift documentation patterns:
/// - Single-line comments with `///`
/// - Multi-line comments with `/** */`
/// - Parameter documentation with `- Parameter name: description`
/// - Parameters list with `- Parameters:` followed by individual parameters
/// - Return documentation with `- Returns:` or `- Return:`
/// - Throws documentation with `- Throws:`
///
/// ## Example
///
/// ```swift
/// let docText = """
/// Performs a calculation with the given values.
/// 
/// - Parameters:
///   - x: The first value
///   - y: The second value
/// - Returns: The calculated result
/// - Throws: `CalculationError` if the operation fails
/// """
/// let doc = Documentation(from: docText)
/// print(doc.description) // "Performs a calculation with the given values."
/// print(doc.parameters["x"]) // "The first value"
/// ```
public struct Documentation: Codable {
    /// The main description text from the documentation comment.
    ///
    /// This contains the primary documentation content, excluding parameter lists,
    /// return information, and throws clauses.
    public let description: String
    
    /// A dictionary mapping parameter names to their documentation descriptions.
    ///
    /// Keys are parameter names and values are their corresponding documentation strings.
    public let parameters: [String: String]
    
    /// Documentation for the return value, if present.
    ///
    /// Contains the text following `- Returns:` or `- Return:` in the documentation comment.
    public let returns: String?
    
    /// Documentation for what the function or method can throw, if present.
    ///
    /// Contains the text following `- Throws:` in the documentation comment.
    public let throwsInfo: String?
    
    /// Parses a documentation comment string into structured components.
    ///
    /// This initializer processes various Swift documentation comment formats and extracts
    /// structured information including descriptions, parameters, return values, and throws information.
    ///
    /// - Parameter text: The raw documentation comment text to parse.
    ///
    /// ## Parsing Logic
    ///
    /// The parser:
    /// 1. Removes comment prefixes (`///`, `/**`, `*/`, `*`)
    /// 2. Identifies section markers (`- Parameter`, `- Parameters:`, `- Returns:`, `- Throws:`)
    /// 3. Groups content into appropriate sections
    /// 4. Handles both inline parameter documentation and parameter lists
    public init(from text: String) {
        var _ = ""
        var params: [String: String] = [:]
        var returnValue: String?
        var throwsValue: String?
        
        let lines = text.components(separatedBy: .newlines)
        var currentSection: DocumentationSection = .description
        var descriptionLines: [String] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Remove comment prefixes
            let cleaned = trimmed.replacingOccurrences(of: "^///\\s*", with: "", options: .regularExpression)
                .replacingOccurrences(of: "^\\*\\s*", with: "", options: .regularExpression)
                .replacingOccurrences(of: "^/\\*\\*\\s*", with: "", options: .regularExpression)
                .replacingOccurrences(of: "\\*/\\s*$", with: "", options: .regularExpression)
            
            if cleaned.isEmpty {
                continue
            }
            
            if cleaned.hasPrefix("- Parameter ") {
                currentSection = .parameters
                let paramLine = String(cleaned.dropFirst("- Parameter ".count))
                if let colonIndex = paramLine.firstIndex(of: ":") {
                    let paramName = String(paramLine[..<colonIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
                    let paramDesc = String(paramLine[paramLine.index(after: colonIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)
                    params[paramName] = paramDesc
                }
            } else if cleaned.hasPrefix("- Parameters:") {
                currentSection = .parameters
            } else if cleaned.hasPrefix("- Returns:") || cleaned.hasPrefix("- Return:") {
                currentSection = .returns
                let returnLine = cleaned.replacingOccurrences(of: "^- Returns?:\\s*", with: "", options: .regularExpression)
                if !returnLine.isEmpty {
                    returnValue = returnLine
                }
            } else if cleaned.hasPrefix("- Throws:") {
                currentSection = .throwsSection
                let throwsLine = cleaned.replacingOccurrences(of: "^- Throws:\\s*", with: "", options: .regularExpression)
                if !throwsLine.isEmpty {
                    throwsValue = throwsLine
                }
            } else if cleaned.hasPrefix("- ") && currentSection == .parameters {
                // Handle parameter in list format: "- paramName: description"
                let paramLine = String(cleaned.dropFirst("- ".count))
                if let colonIndex = paramLine.firstIndex(of: ":") {
                    let paramName = String(paramLine[..<colonIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
                    let paramDesc = String(paramLine[paramLine.index(after: colonIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)
                    params[paramName] = paramDesc
                }
            } else {
                switch currentSection {
                case .description:
                    descriptionLines.append(cleaned)
                case .returns:
                    if returnValue == nil {
                        returnValue = cleaned
                    } else {
                        returnValue! += " " + cleaned
                    }
                case .throwsSection:
                    if throwsValue == nil {
                        throwsValue = cleaned
                    } else {
                        throwsValue! += " " + cleaned
                    }
                case .parameters:
                    // Continue description if we haven't hit a parameter marker
                    if !cleaned.hasPrefix("- ") {
                        descriptionLines.append(cleaned)
                        currentSection = .description
                    }
                }
            }
        }
        
        self.description = descriptionLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        self.parameters = params
        self.returns = returnValue
        self.throwsInfo = throwsValue
    }
}
