import Foundation
import SAAE

// Demo of SAAE functionality
print("🚀 SAAE (Swift AST Abstractor & Editor) Demo")
print("=============================================\n")

// MARK: - Helper Functions

/// Recursively finds all Swift files in a directory
func findSwiftFiles(in directory: URL, recursive: Bool = true) -> [URL] {
    var swiftFiles: [URL] = []
    
    if recursive {
        // Recursive search through all subdirectories
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return swiftFiles
        }
        
        for case let fileURL as URL in enumerator {
            if fileURL.pathExtension == "swift" {
                swiftFiles.append(fileURL)
            }
        }
    } else {
        // Non-recursive - only look in the immediate directory
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
            
            for fileURL in contents {
                if fileURL.pathExtension == "swift" {
                    swiftFiles.append(fileURL)
                }
            }
        } catch {
            // If we can't read the directory, return empty array
            return swiftFiles
        }
    }
    
    return swiftFiles.sorted { $0.path < $1.path }
}

/// Checks if a file has any declarations matching the visibility filter
func hasMatchingDeclarations(_ fileURL: URL, minVisibility: SAAE.VisibilityLevel) -> Bool {
    do {
        let handle = try parse(url: fileURL)
        let overview = try generateOverview(astHandle: handle, format: .json, minVisibility: minVisibility)
        
        // Parse the JSON to check if there are any declarations
        if let data = overview.data(using: .utf8),
           let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let declarations = json["declarations"] as? [[String: Any]] {
            return !declarations.isEmpty
        }
        return false
    } catch {
        return false // If we can't parse it, don't include it
    }
}

/// Processes a single Swift file and generates output
func processFile(_ fileURL: URL, format: OutputFormat, minVisibility: SAAE.VisibilityLevel = .internal) {
    let fileName = fileURL.lastPathComponent
    let relativePath = fileURL.path.replacingOccurrences(of: FileManager.default.currentDirectoryPath + "/", with: "")
    
    print("📂 Analyzing file: \(relativePath)")
    print("🎯 Output format: \(format.stringValue)")
    print("🔒 Minimum visibility: \(minVisibility.stringValue)")
    print("Parsing Swift code...")
    
    do {
        let handle = try parse(url: fileURL)
        print("✅ Code parsed successfully!")
        print("")
        
        print("🔧 Generating \(format.stringValue) overview...")
        let output = try generateOverview(astHandle: handle, format: format, minVisibility: minVisibility)
        print(output)
        print("")
        
    } catch {
        print("❌ Error processing \(fileName): \(error)")
        print("")
    }
}

/// Processes multiple Swift files
func processFiles(_ fileURLs: [URL], format: OutputFormat, minVisibility: SAAE.VisibilityLevel = .internal) {
    // Filter out files that have no matching declarations
    let relevantFiles = fileURLs.filter { fileURL in
        hasMatchingDeclarations(fileURL, minVisibility: minVisibility)
    }
    
    if relevantFiles.isEmpty {
        print("⚠️  No Swift files found with declarations matching visibility level '\(minVisibility.stringValue)'")
        return
    }
    
    if relevantFiles.count == 1 {
        processFile(relevantFiles[0], format: format, minVisibility: minVisibility)
    } else {
        print("📚 Processing \(relevantFiles.count) Swift files")
        print("🎯 Output format: \(format.stringValue)")
        print("🔒 Minimum visibility: \(minVisibility.stringValue)")
        print("")
        
        for (index, fileURL) in relevantFiles.enumerated() {
            let fullPath = fileURL.path
            print("[\(index + 1)/\(relevantFiles.count)] 📄 \(fullPath)")
            print("=" + String(repeating: "=", count: fullPath.count + 6))
            
            do {
                let handle = try parse(url: fileURL)
                let output = try generateOverview(astHandle: handle, format: format, minVisibility: minVisibility)
                print(output)
                
                if index < relevantFiles.count - 1 {
                    print("\n" + String(repeating: "-", count: 50) + "\n")
                }
            } catch {
                print("❌ Error: \(error)")
                if index < relevantFiles.count - 1 {
                    print("\n" + String(repeating: "-", count: 50) + "\n")
                }
            }
        }
    }
}

// MARK: - Argument Parsing

let arguments = CommandLine.arguments
guard arguments.count >= 2 else {
    print("❌ Usage: \(arguments[0]) <path-or-paths> [-f|--format <format>] [-r|--recursive] [-v|--visibility <level>]")
    print("   Supports:")
    print("   • Single file: \(arguments[0]) file.swift")
    print("   • Multiple files: \(arguments[0]) file1.swift file2.swift")
    print("   • Wildcards: \(arguments[0]) Sources/**/*.swift (expanded by shell)")
    print("   • Directory: \(arguments[0]) Sources/SAAE (files in directory only)")
    print("   • Directory recursive: \(arguments[0]) Sources -r (all Swift files in subdirectories)")
    print("   • Format options: json, yaml, markdown, interface (default: interface)")
    print("   • Visibility: private, fileprivate, internal, package, public, open (default: internal)")
    print("")
    print("   Examples:")
    print("     \(arguments[0]) Sources/SAAE/SAAE.swift")
    print("     \(arguments[0]) Sources/SAAE/*.swift -f json")
    print("     \(arguments[0]) Sources/SAAE --format markdown")
    print("     \(arguments[0]) Sources/SAAE                          # Files in Sources/SAAE only")
    print("     \(arguments[0]) Sources -r -f yaml                    # All files in Sources and subdirectories")
    print("     \(arguments[0]) Sources --recursive --format json     # Same as above with long flags")
    print("     \(arguments[0]) Sources/SAAE -v public -f interface   # Only public and open declarations")
    print("     \(arguments[0]) Sources/SAAE --visibility private     # All declarations including private")
    print("     \(arguments[0]) file1.swift file2.swift -f yaml")
    exit(1)
}

// Parse format from arguments
var format: OutputFormat = .interface
var inputPaths: [String] = []
var recursive: Bool = false  // Default to non-recursive
var minVisibility: SAAE.VisibilityLevel = .internal

var i = 1
while i < arguments.count {
    let arg = arguments[i]
    
    if arg == "-f" || arg == "--format" {
        guard i + 1 < arguments.count else {
            print("❌ Error: \(arg) flag requires a value")
            print("   Valid formats: json, yaml, markdown, interface")
            exit(1)
        }
        
        i += 1
        let formatString = arguments[i]
        
        switch formatString.lowercased() {
        case "json":
            format = .json
        case "yaml":
            format = .yaml
        case "markdown":
            format = .markdown
        case "interface":
            format = .interface
        default:
            print("❌ Error: Invalid format '\(formatString)'")
            print("   Valid formats: json, yaml, markdown, interface")
            exit(1)
        }
    } else if arg == "-r" || arg == "--recursive" {
        recursive = true
    } else if arg == "-v" || arg == "--visibility" {
        guard i + 1 < arguments.count else {
            print("❌ Error: \(arg) flag requires a value")
            print("   Valid visibility levels: private, fileprivate, internal, package, public, open")
            exit(1)
        }
        
        i += 1
        let visibilityString = arguments[i]
        
        switch visibilityString.lowercased() {
        case "private":
            minVisibility = .private
        case "fileprivate":
            minVisibility = .fileprivate
        case "internal":
            minVisibility = .internal
        case "package":
            minVisibility = .package
        case "public":
            minVisibility = .public
        case "open":
            minVisibility = .open
        default:
            print("❌ Error: Invalid visibility level '\(visibilityString)'")
            print("   Valid visibility levels: private, fileprivate, internal, package, public, open")
            exit(1)
        }
    } else if arg.hasPrefix("-") {
        print("❌ Error: Unknown flag '\(arg)'")
        print("   Valid flags: -f, --format, -r, --recursive, -v, --visibility")
        exit(1)
    } else {
        inputPaths.append(arg)
    }
    
    i += 1
}

guard !inputPaths.isEmpty else {
    print("❌ Error: No input files or directories specified")
    exit(1)
}

// MARK: - File Discovery and Processing

var allFiles: [URL] = []

for inputPath in inputPaths {
    // Handle tilde expansion
    let expandedPath = NSString(string: inputPath).expandingTildeInPath
    
    // Determine if this is an absolute or relative path
    let fileURL: URL
    if expandedPath.hasPrefix("/") {
        fileURL = URL(fileURLWithPath: expandedPath)
    } else {
        let currentDirectory = FileManager.default.currentDirectoryPath
        fileURL = URL(fileURLWithPath: currentDirectory).appendingPathComponent(expandedPath).standardized
    }
    
    // Check if path exists
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
        print("❌ Error: Path does not exist: \(inputPath)")
        continue
    }
    
    // Check if it's a directory or file
    var isDirectory: ObjCBool = false
    FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDirectory)
    
    if isDirectory.boolValue {
        // It's a directory - find all Swift files recursively
        let swiftFiles = findSwiftFiles(in: fileURL, recursive: recursive)
        if swiftFiles.isEmpty {
            print("⚠️  No Swift files found in directory: \(inputPath)")
        } else {
            allFiles.append(contentsOf: swiftFiles)
        }
    } else {
        // It's a file - check if it's a Swift file
        if fileURL.pathExtension == "swift" {
            allFiles.append(fileURL)
        } else {
            print("⚠️  Skipping non-Swift file: \(inputPath)")
        }
    }
}

// Remove duplicates while preserving order
var seenPaths: Set<String> = []
allFiles = allFiles.filter { file in
    let path = file.path
    if seenPaths.contains(path) {
        return false
    } else {
        seenPaths.insert(path)
        return true
    }
}

guard !allFiles.isEmpty else {
    print("❌ Error: No Swift files found to process")
    exit(1)
}

// Process all discovered files
processFiles(allFiles, format: format, minVisibility: minVisibility) 
