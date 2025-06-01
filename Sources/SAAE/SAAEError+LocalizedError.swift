import Foundation

extension SAAEError: LocalizedError {
/// Provides a localized description of the error for user presentation.
///
/// - Returns: A human-readable error message describing what went wrong.
    public var errorDescription: String? {
    switch self {
        case .fileNotFound(let url):
            return "File not found: \(url.path)"
        case .fileReadError(let url, let error):
            return "Error reading file \(url.path): \(error.localizedDescription)"
    }
}
}
