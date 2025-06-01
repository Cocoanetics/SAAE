import Foundation

/// Container structure for multi-file analysis results.
///
/// This structure organizes the results of analyzing multiple Swift files,
/// providing a top-level container for all file-specific overviews.
internal struct MultiFileCodeOverview: Codable {
/// Array of individual file analysis results.
    internal let files: [FileOverview]

/// Creates a multi-file overview from individual file results.
///
/// - Parameter files: Array of file overview results.
    internal init(files: [FileOverview]) {
        self.files = files
    }
}
