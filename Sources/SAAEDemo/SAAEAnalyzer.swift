import Foundation
import SAAE

/// Handles the analysis of Swift source code files using the appropriate SAAE components.
///
/// This analyzer coordinates between single-file analysis using the SAAE class
/// and multi-file analysis using ProjectOverview, providing a unified interface
/// for the command-line tool.
class SAAEAnalyzer {
    let paths: [String]
    let format: OutputFormat
    let visibility: VisibilityLevel
    let recursive: Bool
    
    init(paths: [String], format: OutputFormat, visibility: VisibilityLevel, recursive: Bool) {
        self.paths = paths
        self.format = format
        self.visibility = visibility
        self.recursive = recursive
    }
    
    func analyze() async throws -> String {
        let fileURLs = try discoverFiles()
        
        guard !fileURLs.isEmpty else {
            throw NSError(domain: "SAAE", code: 1, userInfo: [NSLocalizedDescriptionKey: "No Swift files found in the specified paths"])
        }
        
        let relevantFiles = fileURLs.filter { hasMatchingDeclarations($0, minVisibility: visibility) }
        
        if relevantFiles.isEmpty {
            throw NSError(domain: "SAAE", code: 2, userInfo: [NSLocalizedDescriptionKey: "No files found with \(visibility.rawValue) or higher visibility declarations"])
        }
        
        return try await processFiles(relevantFiles)
    }
    
    private func discoverFiles() throws -> [URL] {
        var allFileURLs: [URL] = []
        
        for inputPath in paths {
            let url: URL
            
            // Handle tilde expansion for paths starting with ~
            if inputPath.hasPrefix("~") {
                let expandedPath = NSString(string: inputPath).expandingTildeInPath
                url = URL(fileURLWithPath: expandedPath)
            } else {
                url = URL(fileURLWithPath: inputPath)
            }
            
            let fileManager = FileManager.default
            var isDirectory: ObjCBool = false
            
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
                throw NSError(domain: "SAAE", code: 3, userInfo: [NSLocalizedDescriptionKey: "Path does not exist: \(inputPath)"])
            }
            
            if isDirectory.boolValue {
                // It's a directory
                if recursive {
                    // Recursive directory search for .swift files
                    if let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
                        for case let fileURL as URL in enumerator {
                            if fileURL.pathExtension == "swift" {
                                allFileURLs.append(fileURL)
                            }
                        }
                    }
                } else {
                    // Non-recursive: only direct children
                    let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
                    for fileURL in contents {
                        if fileURL.pathExtension == "swift" {
                            allFileURLs.append(fileURL)
                        }
                    }
                }
            } else {
                // It's a file
                if url.pathExtension == "swift" {
                    allFileURLs.append(url)
                } else {
                    print("⚠️  Warning: Skipping non-Swift file: \(url.path)")
                }
            }
        }
        
        // Sort the URLs for consistent output
        return allFileURLs.sorted { $0.path < $1.path }
    }
    
    private func processFiles(_ fileURLs: [URL]) async throws -> String {
        if fileURLs.count == 1 {
            return try processSingleFile(fileURLs[0])
        } else {
            return try processMultipleFiles(fileURLs)
        }
    }
    
    private func processSingleFile(_ fileURL: URL) throws -> String {
        let tree = try SyntaxTree(url: fileURL)
        let overview = CodeOverview(tree: tree, minVisibility: visibility)
        
        switch format {
        case .json:
            return try overview.json()
        case .yaml:
            return try overview.yaml()
        case .markdown:
            return overview.markdown()
        case .interface:
            return overview.interface()
        }
    }
    
    private func processMultipleFiles(_ fileURLs: [URL]) throws -> String {
        let projectOverview = try ProjectOverview(
            fileURLs: fileURLs,
            minVisibility: visibility
        )
        return try projectOverview.generateOverview(format: format)
    }
    
    private func hasMatchingDeclarations(_ fileURL: URL, minVisibility: VisibilityLevel) -> Bool {
        do {
            let tree = try SyntaxTree(url: fileURL)
            let overview = CodeOverview(tree: tree, minVisibility: minVisibility)
            return !overview.declarations.isEmpty
        } catch {
            return false
        }
    }
} 