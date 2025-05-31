import Foundation

/// Defines the available output formats for Swift code analysis results.
///
/// This enum specifies the different ways that analyzed Swift code can be formatted and presented.
/// Each format serves different use cases, from machine-readable data exchange to human-readable documentation.
///
/// ## Available Formats
///
/// - **JSON**: Structured data format ideal for programmatic consumption
/// - **YAML**: Human-readable data serialization format
/// - **Markdown**: Documentation format suitable for README files and documentation sites
/// - **Interface**: Swift-like interface declarations showing public API signatures
///
/// ## Usage
///
/// ```swift
/// let saae = SAAE()
/// let result = try saae.generateOverview(
///     url: fileURL, 
///     format: .markdown, 
///     minVisibility: .public
/// )
/// ```
public enum OutputFormat: String, CaseIterable {
    /// JSON format - structured data ideal for programmatic consumption and API integration.
    case json
    
    /// YAML format - human-readable structured data format that's easier to read than JSON.
    case yaml
    
    /// Markdown format - documentation-friendly format suitable for README files and documentation sites.
    case markdown
    
    /// Interface format - Swift-like interface declarations showing clean API signatures without implementation details.
    case interface
}
