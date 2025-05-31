import Foundation
import Yams

/// Provides comprehensive analysis of multiple Swift files as a cohesive project.
///
/// `ProjectOverview` coordinates the analysis of multiple Swift source files,
/// organizing their individual overviews into a unified project-level view.
/// It handles the complexity of multi-file relationships and provides
/// consolidated output in various formats.
///
/// ## Usage
///
/// ```swift
/// let projectOverview = ProjectOverview(
///     fileURLs: [file1URL, file2URL, file3URL],
///     minVisibility: .public
/// )
/// let markdownDoc = try projectOverview.generateOverview(format: .markdown)
/// ```
///
/// ## Output Formats
///
/// - **JSON/YAML**: Structured data with file metadata and cross-references
/// - **Markdown**: Comprehensive documentation with file navigation
/// - **Interface**: Concatenated interface declarations with file separators
public struct ProjectOverview {
    
    /// Individual file analysis results.
    internal let fileOverviews: [FileOverview]
    
    /// The minimum visibility level applied across all files.
    internal let minVisibility: VisibilityLevel
    
    /// Creates a project overview by analyzing multiple Swift files.
    ///
    /// This initializer processes each file URL, performs individual analysis,
    /// and organizes the results for project-level consumption.
    ///
    /// - Parameters:
    ///   - fileURLs: Array of file URLs pointing to Swift source files to analyze.
    ///   - minVisibility: The minimum visibility level to include in the analysis.
    ///
    /// - Throws:
    ///   - ``SAAEError/fileNotFound(_:)`` if any specified file doesn't exist.
    ///   - ``SAAEError/fileReadError(_:_:)`` if any file cannot be read.
    public init(fileURLs: [URL], minVisibility: VisibilityLevel = .internal) throws {
        self.minVisibility = minVisibility
        var results: [FileOverview] = []
        
        for url in fileURLs {
            let tree = try SyntaxTree(url: url)
            let overview = CodeOverview(tree: tree, minVisibility: minVisibility)
            
            let fileOverview = FileOverview(
                path: url.path,
                imports: overview.imports,
                declarations: overview.declarations
            )
            results.append(fileOverview)
        }
        
        self.fileOverviews = results
    }
    
    /// Generates a comprehensive overview of the project in the specified format.
    ///
    /// This method consolidates the individual file analyses into a unified
    /// project overview, with format-specific organization and presentation.
    ///
    /// - Parameter format: The desired output format for the project overview.
    /// - Returns: A string containing the project overview in the specified format.
    /// - Throws: Encoding errors if the output format cannot be generated.
    ///
    /// ## Format-Specific Behavior
    ///
    /// - **JSON/YAML**: Creates a structured object with file metadata and declarations
    /// - **Markdown**: Generates a comprehensive document with file sections and navigation
    /// - **Interface**: Concatenates interface declarations with clear file separators
    public func generateOverview(format: OutputFormat) throws -> String {
        switch format {
        case .json:
            let multiFileOverview = MultiFileCodeOverview(files: fileOverviews)
            return try generateJSONOutput(multiFileOverview)
        case .yaml:
            let multiFileOverview = MultiFileCodeOverview(files: fileOverviews)
            return try generateYAMLOutput(multiFileOverview)
        case .markdown:
            return generateMarkdownOutput()
        case .interface:
            return generateInterfaceOutput()
        }
    }
    
    /// The file system paths of all analyzed files.
    ///
    /// Provides access to the paths of all files included in this project overview,
    /// useful for debugging and reporting purposes.
    public var filePaths: [String] {
        return fileOverviews.map { $0.path }
    }
    
    /// The total number of declarations across all files.
    ///
    /// Provides a quick metric of the project size in terms of analyzed declarations.
    public var totalDeclarationCount: Int {
        return fileOverviews.reduce(0) { $0 + $1.declarations.count }
    }
    
    /// All unique import statements across the project.
    ///
    /// Consolidates imports from all files, providing a view of the project's
    /// external dependencies.
    public var allImports: [String] {
        let allImports = fileOverviews.flatMap { $0.imports }
        return Array(Set(allImports)).sorted()
    }
}
