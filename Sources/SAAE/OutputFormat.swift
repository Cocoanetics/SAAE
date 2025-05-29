import Foundation

/// Output format for the overview generation
public enum OutputFormat {
    case json
    case yaml
    case markdown
    case interface
    
    /// String representation of the output format
    public var stringValue: String {
        switch self {
        case .json:
            return "JSON"
        case .yaml:
            return "YAML"
        case .markdown:
            return "Markdown"
        case .interface:
            return "Interface"
        }
    }
} 