import Foundation
import SAAE

/// Handles the analysis of Swift source code files
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
        if format == .json || format == .yaml {
            // For JSON and YAML, we need to combine results differently
            // Since we can't create a combined CodeOverview directly, we'll combine the outputs
            var allResults: [[String: Any]] = []
            
            for fileURL in fileURLs {
                let tree = try SyntaxTree(url: fileURL)
                let overview = CodeOverview(tree: tree, minVisibility: visibility)
                
                // Convert to a dictionary representation
                let result: [String: Any] = [
                    "file": fileURL.lastPathComponent,
                    "imports": overview.imports,
                    "declarations": overview.declarations.map { $0.toDictionary() }
                ]
                allResults.append(result)
            }
            
            // Combine all results
            let combined: [String: Any] = [
                "files": allResults
            ]
            
            switch format {
            case .json:
                let data = try JSONSerialization.data(withJSONObject: combined, options: [.prettyPrinted, .sortedKeys])
                return String(data: data, encoding: .utf8) ?? ""
            case .yaml:
                // For YAML, let's just concatenate the individual results
                var yamlResults: [String] = []
                for fileURL in fileURLs {
                    let tree = try SyntaxTree(url: fileURL)
                    let overview = CodeOverview(tree: tree, minVisibility: visibility)
                    let yaml = try overview.yaml()
                    yamlResults.append("# File: \(fileURL.lastPathComponent)\n\(yaml)")
                }
                return yamlResults.joined(separator: "\n---\n\n")
            default:
                fatalError("Unexpected format")
            }
        } else {
            // For markdown and interface, process files individually
            var results: [String] = []
            
            for fileURL in fileURLs {
                let tree = try SyntaxTree(url: fileURL)
                let overview = CodeOverview(tree: tree, minVisibility: visibility)
                
                let output: String
                switch format {
                case .markdown:
                    output = overview.markdown()
                case .interface:
                    output = overview.interface()
                default:
                    fatalError("Unexpected format")
                }
                
                results.append(output)
            }
            
            return results.joined(separator: "\n" + String(repeating: "=", count: 80) + "\n")
        }
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