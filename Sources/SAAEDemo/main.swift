import Foundation
import SAAE

// Demo of SAAE functionality
print("🚀 SAAE (Swift AST Abstractor & Editor) Demo")
print("=============================================\n")

// MARK: - Helper Functions

/// Recursively finds all Swift files in a directory
func findSwiftFiles(in directory: URL) -> [URL] {
    var swiftFiles: [URL] = []
    
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
    
    return swiftFiles.sorted { $0.path < $1.path }
}

/// Processes a single Swift file and generates output
func processFile(_ fileURL: URL, format: OutputFormat) {
    let fileName = fileURL.lastPathComponent
    let relativePath = fileURL.path.replacingOccurrences(of: FileManager.default.currentDirectoryPath + "/", with: "")
    
    print("📂 Analyzing file: \(relativePath)")
    print("🎯 Output format: \(format.stringValue)")
    print("Parsing Swift code...")
    
    do {
        let handle = try parse(url: fileURL)
        print("✅ Code parsed successfully!")
        print("")
        
        print("🔧 Generating \(format.stringValue) overview...")
        let output = try generateOverview(astHandle: handle, format: format)
        print(output)
        print("")
        
    } catch {
        print("❌ Error processing \(fileName): \(error)")
        print("")
    }
}

/// Processes multiple Swift files
func processFiles(_ fileURLs: [URL], format: OutputFormat) {
    if fileURLs.count == 1 {
        processFile(fileURLs[0], format: format)
    } else {
        print("📚 Processing \(fileURLs.count) Swift files")
        print("🎯 Output format: \(format.stringValue)")
        print("")
        
        for (index, fileURL) in fileURLs.enumerated() {
            let fullPath = fileURL.path
            print("[\(index + 1)/\(fileURLs.count)] 📄 \(fullPath)")
            print("=" + String(repeating: "=", count: fullPath.count + 6))
            
            do {
                let handle = try parse(url: fileURL)
                let output = try generateOverview(astHandle: handle, format: format)
                print(output)
                
                if index < fileURLs.count - 1 {
                    print("\n" + String(repeating: "-", count: 50) + "\n")
                }
            } catch {
                print("❌ Error: \(error)")
                if index < fileURLs.count - 1 {
                    print("\n" + String(repeating: "-", count: 50) + "\n")
                }
            }
        }
    }
}

// MARK: - Argument Parsing

let arguments = CommandLine.arguments
guard arguments.count >= 2 else {
    print("❌ Usage: \(arguments[0]) <path-or-paths> [-f|--format <format>]")
    print("   Supports:")
    print("   • Single file: \(arguments[0]) file.swift")
    print("   • Multiple files: \(arguments[0]) file1.swift file2.swift")
    print("   • Wildcards: \(arguments[0]) Sources/**/*.swift (expanded by shell)")
    print("   • Directory: \(arguments[0]) Sources/SAAE")
    print("   • Format options: json, yaml, markdown, interface (default: interface)")
    print("")
    print("   Examples:")
    print("     \(arguments[0]) Sources/SAAE/SAAE.swift")
    print("     \(arguments[0]) Sources/SAAE/*.swift -f json")
    print("     \(arguments[0]) Sources/SAAE --format markdown")
    print("     \(arguments[0]) file1.swift file2.swift -f yaml")
    exit(1)
}

// Parse format from arguments
var format: OutputFormat = .interface
var inputPaths: [String] = []

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
    } else if arg.hasPrefix("-") {
        print("❌ Error: Unknown flag '\(arg)'")
        print("   Valid flags: -f, --format")
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
        let swiftFiles = findSwiftFiles(in: fileURL)
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
processFiles(allFiles, format: format) 
