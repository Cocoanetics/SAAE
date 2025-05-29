import Foundation

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