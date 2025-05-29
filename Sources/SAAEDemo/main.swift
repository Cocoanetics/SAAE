import Foundation
import SAAE

// Demo of SAAE functionality
print("🚀 SAAE (Swift AST Abstractor & Editor) Demo")
print("=============================================\n")

// Check for command line arguments
let arguments = CommandLine.arguments
guard arguments.count >= 2 else {
    print("❌ Usage: \(arguments[0]) <path-to-swift-file> [-f|--format <format>]")
    print("   The path can be absolute, relative, or use tilde (~) for home directory")
    print("   Format options: json, yaml, markdown, interface (default: interface)")
    print("")
    print("   Examples:")
    print("     \(arguments[0]) Sources/SAAE/SAAE.swift                        # Interface format (default)")
    print("     \(arguments[0]) Sources/SAAE/SAAE.swift -f interface           # Interface format")
    print("     \(arguments[0]) Sources/SAAE/SAAE.swift --format json          # JSON format")
    print("     \(arguments[0]) Sources/SAAE/SAAE.swift -f yaml                # YAML format")
    print("     \(arguments[0]) Sources/SAAE/SAAE.swift --format markdown      # Markdown format")
    print("     \(arguments[0]) /absolute/path/to/file.swift -f json           # Absolute path with JSON")
    print("     \(arguments[0]) ~/Desktop/MySwiftFile.swift --format markdown  # Tilde path with Markdown")
    exit(1)
}

let inputPath = arguments[1]

// Parse output format from flags (default to interface)
var outputFormat: OutputFormat = .interface
var i = 2
while i < arguments.count {
    let arg = arguments[i]
    
    if arg == "-f" || arg == "--format" {
        // Check if there's a value after the flag
        guard i + 1 < arguments.count else {
            print("❌ Error: \(arg) flag requires a value. Valid options are: json, yaml, markdown, interface")
            exit(1)
        }
        
        let formatString = arguments[i + 1].lowercased()
        switch formatString {
        case "json":
            outputFormat = .json
        case "yaml":
            outputFormat = .yaml
        case "markdown":
            outputFormat = .markdown
        case "interface":
            outputFormat = .interface
        default:
            print("❌ Error: Invalid format '\(arguments[i + 1])'. Valid options are: json, yaml, markdown, interface")
            exit(1)
        }
        i += 2  // Skip both flag and value
    } else {
        print("❌ Error: Unknown argument '\(arg)'. Use -f or --format to specify output format.")
        exit(1)
    }
}

let fileURL: URL

// Handle all path types: absolute, relative, and tilde paths
if inputPath.hasPrefix("~") {
    // Tilde path - expand home directory
    let expandedPath = NSString(string: inputPath).expandingTildeInPath
    fileURL = URL(fileURLWithPath: expandedPath).standardized
} else if inputPath.hasPrefix("/") {
    // Absolute path
    fileURL = URL(fileURLWithPath: inputPath).standardized
} else {
    // Relative path - resolve relative to current working directory
    let currentDirectory = FileManager.default.currentDirectoryPath
    fileURL = URL(fileURLWithPath: currentDirectory).appendingPathComponent(inputPath).standardized
}

print("📂 Analyzing file: \(fileURL.path)")
print("🎯 Output format: \(String(describing: outputFormat).capitalized)")

do {
    print("Parsing Swift code...")
    let handle = try parse(url: fileURL)
    
    print("✅ Code parsed successfully!")
    
    // Generate appropriate format name for display
    let formatName: String
    switch outputFormat {
    case .json:
        formatName = "JSON"
    case .yaml:
        formatName = "YAML"
    case .markdown:
        formatName = "Markdown"
    case .interface:
        formatName = "Interface"
    }
    
    print("\n🔧 Generating \(formatName) overview...")
    let overview = try generateOverview(astHandle: handle, format: outputFormat)
    print(overview)
    
} catch {
    print("❌ Error: \(error)")
    exit(1)
} 
