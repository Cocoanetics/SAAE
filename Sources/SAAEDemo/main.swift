import Foundation
import SAAE

// Demo of SAAE functionality
print("🚀 SAAE (Swift AST Abstractor & Editor) Demo")
print("=============================================\n")

// Check for command line arguments
let arguments = CommandLine.arguments
guard arguments.count >= 2 else {
    print("❌ Usage: \(arguments[0]) <path-to-swift-file>")
    print("   The path can be absolute, relative, or use tilde (~) for home directory")
    print("   Examples:")
    print("     \(arguments[0]) Sources/SAAE/SAAE.swift                    # Relative path")
    print("     \(arguments[0]) /Users/username/project/MyFile.swift       # Absolute path")
    print("     \(arguments[0]) ~/Desktop/MySwiftFile.swift                # Tilde path")
    exit(1)
}

let inputPath = arguments[1]
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

do {
    print("Parsing Swift code...")
    let handle = try parse(url: fileURL)
    
    print("✅ Code parsed successfully!")
    
    print("\n🔧 Generating Interface overview...")
    let interfaceOverview = try generateOverview(astHandle: handle, format: .interface)
    print(interfaceOverview)
    
} catch {
    print("❌ Error: \(error)")
    exit(1)
} 
