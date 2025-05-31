import Foundation

/// Represents errors that can occur during SAAE operations.
///
/// This error type provides detailed information about failures that can happen
/// while processing Swift source files, including file system errors and parsing issues.
///
/// ## Error Cases
///
/// - ``SAAEError/fileNotFound(_:)`` - When a specified file cannot be located
/// - ``SAAEError/fileReadError(_:_:)`` - When a file exists but cannot be read due to permissions or other I/O issues
///
/// ## Usage
///
/// ```swift
/// do {
///     let result = try saae.generateOverview(url: fileURL)
/// } catch let error as SAAEError {
///     print("SAAE Error: \(error.localizedDescription)")
/// }
/// ```
public enum SAAEError: Error {
    /// Indicates that the specified file could not be found at the given URL.
    ///
    /// - Parameter URL: The file URL that could not be located.
    case fileNotFound(URL)
    
    /// Indicates that a file was found but could not be read due to an underlying error.
    ///
    /// This typically occurs due to permission issues, file corruption, or other I/O problems.
    ///
    /// - Parameters:
    ///   - URL: The file URL that could not be read.
    ///   - Error: The underlying error that caused the read failure.
    case fileReadError(URL, Error)
}
