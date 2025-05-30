import Foundation
import SAAE
import ArgumentParser

#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

// ArgumentParser conformance for SAAE types
extension OutputFormat: @retroactive ExpressibleByArgument {}
extension VisibilityLevel: @retroactive ExpressibleByArgument {}

/// SAAE Demo - Swift AST Abstractor & Editor
///
/// This demo application showcases SAAE's ability to parse Swift source code
/// and generate clean, structured overviews in various formats.
@main
struct SAAECommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "SAAEDemo",
        abstract: "A utility for analyzing Swift source code and generating API overviews",
        discussion: """
  Parse Swift source code and generate clean, structured overviews of your API declarations.
  Perfect for efficiently providing LLMs with comprehensive API overviews instead of overwhelming them with entire codebases.
  
  Examples:
    SAAEDemo Sources/SAAE/SAAE.swift
    SAAEDemo Sources/SAAE/*.swift -f json
    SAAEDemo Sources/SAAE --format markdown
    SAAEDemo Sources/SAAE                          # Files in Sources/SAAE only
    SAAEDemo Sources -r -f yaml                    # All files in Sources and subdirectories
    SAAEDemo Sources --recursive --format json     # Same as above with long flags
    SAAEDemo Sources/SAAE -v public -f interface   # Only public and open declarations
    SAAEDemo Sources/SAAE --visibility private     # All declarations including private
    SAAEDemo file1.swift file2.swift -f yaml
"""
    )
    
    @Argument(help: "Swift file(s) or directory to analyze")
    var paths: [String]
    
    @Option(name: .shortAndLong, help: "Output format")
    var format: OutputFormat = .interface
    
    @Flag(name: .shortAndLong, help: "Recursively search directories for Swift files")
    var recursive: Bool = false
    
    @Option(name: .shortAndLong, help: "Minimum visibility level to include")
    var visibility: VisibilityLevel = .internal
    
    @Option(name: .shortAndLong, help: "Output file path (optional, prints to stdout if not specified)")
    var output: String?
    
    func run() async throws {
        print("🚀 SAAE (Swift AST Abstractor & Editor) Demo")
        print("=============================================\n")
        
        let analyzer = SAAEAnalyzer(
            paths: paths,
            format: format,
            visibility: visibility,
            recursive: recursive
        )
        
        let result = try await analyzer.analyze()
        
        if let outputPath = output {
            try result.write(to: URL(fileURLWithPath: outputPath), atomically: true, encoding: .utf8)
            print("✅ Output written to: \(outputPath)")
        } else {
            print(result)
        }
    }
} 