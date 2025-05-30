import Foundation
import SAAE
import ArgumentParser

#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

// ArgumentParser conformance for SAAE types
extension OutputFormat: ExpressibleByArgument {}
extension VisibilityLevel: ExpressibleByArgument {}

/// SAAE Demo - Swift AST Abstractor & Editor
///
/// This demo application showcases SAAE's ability to parse Swift source code
/// and generate clean, structured overviews in various formats.
@main
struct SAAECommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "SAAEDemo",
        abstract: "A utility for analyzing Swift source code and generating API overviews",
        subcommands: [AnalyzeCommand.self, ErrorsCommand.self],
        defaultSubcommand: AnalyzeCommand.self
    )
}

// MARK: - Analyze Subcommand (Original functionality)

struct AnalyzeCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "analyze",
        abstract: "Generate API overviews from Swift source code",
        discussion: """
  Parse Swift source code and generate clean, structured overviews of your API declarations.
  Perfect for efficiently providing LLMs with comprehensive API overviews instead of overwhelming them with entire codebases.
  
  Examples:
    SAAEDemo analyze Sources/SAAE/SAAE.swift
    SAAEDemo analyze Sources/SAAE/*.swift -f json
    SAAEDemo analyze Sources/SAAE --format markdown
    SAAEDemo analyze Sources/SAAE                          # Files in Sources/SAAE only
    SAAEDemo analyze Sources -r -f yaml                    # All files in Sources and subdirectories
    SAAEDemo analyze Sources/SAAE -v public -f interface   # Only public and open declarations
    SAAEDemo analyze Sources/SAAE --visibility private     # All declarations including private
    SAAEDemo analyze file1.swift file2.swift -f yaml
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

// MARK: - Errors Subcommand (New Phase 2 functionality)

enum ErrorOutputFormat: String, CaseIterable, ExpressibleByArgument {
    case json
    case markdown
    
    var defaultValueDescription: String {
        switch self {
        case .json: return "JSON format"
        case .markdown: return "Markdown format"
        }
    }
}

struct ErrorsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "errors",
        abstract: "Detect and report syntax errors in Swift source files",
        discussion: """
  Analyze Swift source files for syntax errors and output detailed error information in JSON or Markdown format.
  This uses SAAE's Phase 2 syntax error detection capabilities to provide comprehensive error reports.
  
  Examples:
    SAAEDemo errors file.swift                     # Check single file (JSON output)
    SAAEDemo errors *.swift                        # Check multiple files
    SAAEDemo errors Sources/ --recursive           # Check directory recursively
    SAAEDemo errors file.swift --output errors.json  # Save JSON to file
    SAAEDemo errors file.swift --format markdown  # Markdown output
    SAAEDemo errors file.swift -f markdown -o errors.md  # Save Markdown to file
    SAAEDemo errors file.swift --pretty            # Pretty-print JSON
    SAAEDemo errors file.swift --show-fixits       # Show fix-it suggestions (like swiftc -fixit)
"""
    )
    
    @Argument(help: "Swift file(s) or directory to check for syntax errors")
    var paths: [String]
    
    @Flag(name: .shortAndLong, help: "Recursively search directories for Swift files")
    var recursive: Bool = false
    
    @Option(name: .shortAndLong, help: "Output file path (optional, prints to stdout if not specified)")
    var output: String?
    
    @Option(name: .shortAndLong, help: "Output format")
    var format: ErrorOutputFormat = .json
    
    @Flag(help: "Pretty-print JSON output (ignored for markdown)")
    var pretty: Bool = false
    
    @Flag(help: "Show fix-it suggestions (like swiftc -fixit)")
    var showFixits: Bool = false
    
    func run() async throws {
        print("🔍 SAAE Syntax Error Detection")
        print("==============================\n")
        
        let swiftFiles = try collectSwiftFiles(from: paths, recursive: recursive)
        
        if swiftFiles.isEmpty {
            print("❌ No Swift files found in the specified paths.")
            throw ExitCode.failure
        }
        
        print("📁 Found \(swiftFiles.count) Swift file(s) to analyze...")
        
        var allErrors: [FileErrorReport] = []
        var totalErrorCount = 0
        
        for filePath in swiftFiles {
            let url = URL(fileURLWithPath: filePath)
            
            do {
                let tree = try SyntaxTree(url: url)
                let errors = tree.syntaxErrors
                
                if !errors.isEmpty {
                    let report = FileErrorReport(
                        filePath: filePath,
                        fileName: url.lastPathComponent,
                        errorCount: errors.count,
                        errors: errors.map { ErrorDetail(from: $0) }
                    )
                    allErrors.append(report)
                    totalErrorCount += errors.count
                    print("❌ \(filePath): \(errors.count) error(s)")
                } else {
                    print("✅ \(filePath): No errors")
                }
                
            } catch {
                print("⚠️  \(filePath): Failed to analyze - \(error)")
                let report = FileErrorReport(
                    filePath: filePath,
                    fileName: url.lastPathComponent,
                    errorCount: 0,
                    errors: [],
                    analysisError: error.localizedDescription
                )
                allErrors.append(report)
            }
        }
        
        let summary = ErrorSummary(
            totalFilesAnalyzed: swiftFiles.count,
            filesWithErrors: allErrors.filter { $0.errorCount > 0 }.count,
            totalErrors: totalErrorCount,
            files: allErrors
        )
        
        // Generate output based on format
        let outputContent: String
        switch format {
        case .json:
            outputContent = try generateJSONOutput(summary: summary)
        case .markdown:
            outputContent = generateMarkdownReport(summary)
        }
        
        if let outputPath = output {
            try outputContent.write(to: URL(fileURLWithPath: outputPath), atomically: true, encoding: .utf8)
            print("\n✅ Error report written to: \(outputPath)")
        } else {
            switch format {
            case .json:
                print("\n📋 Error Report JSON:")
            case .markdown:
                print("\n📋 Error Report Markdown:")
            }
            print(outputContent)
        }
        
        // Exit with error code if syntax errors were found
        if totalErrorCount > 0 && format == .json {
            print("\n❌ Found \(totalErrorCount) syntax error(s) across \(allErrors.filter { $0.errorCount > 0 }.count) file(s)")
            throw ExitCode.failure
        } else if totalErrorCount == 0 && format == .json {
            print("\n✅ No syntax errors found!")
        }
    }
    
    private func generateJSONOutput(summary: ErrorSummary) throws -> String {
        let encoder = JSONEncoder()
        if pretty {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }
        
        let jsonData = try encoder.encode(summary)
        return String(data: jsonData, encoding: .utf8) ?? ""
    }
    
    private func generateMarkdownReport(_ summary: ErrorSummary) -> String {
        var markdown = ""
        
        let filesWithErrors = summary.files.filter { $0.errorCount > 0 }
        
        if filesWithErrors.isEmpty {
            markdown += "✅ **No syntax errors found!**\n\n"
            markdown += "All analyzed files are syntactically correct.\n"
            return markdown
        }
        
        for fileReport in filesWithErrors {
            for error in fileReport.errors {
                // Smart error line detection
                let contextLines = error.sourceContext
                let rangeParts = error.contextRange.components(separatedBy: "-")
                let contextStartLine = Int(rangeParts.first ?? "1") ?? 1
                let maxLineNumber = contextStartLine + contextLines.count - 1
                let lineNumberWidth = String(maxLineNumber).count
                
                // Use the SwiftSyntax-reported line directly (our tests prove it's accurate)
                let reportedLineIndex = error.location.line - contextStartLine
                let actualErrorLine = error.location.line
                
                // Header: file:line:col: error: message
                markdown += "\(fileReport.filePath):\(actualErrorLine):\(error.location.column): error: \(error.message)\n"
                for (index, line) in contextLines.enumerated() {
                    let lineNumber = contextStartLine + index
                    let isErrorLine = (index == reportedLineIndex)
                    let prefix = String(format: "%*d | ", lineNumberWidth, lineNumber)
                    markdown += prefix + line + "\n"
                    if isErrorLine {
                        // swiftc style error line: "  |             `- error: message"
                        let errorColumnPos = max(0, error.location.column - 1)
                        let leadingSpaces = String(repeating: " ", count: lineNumberWidth)
                        let pipeSpaces = String(repeating: " ", count: errorColumnPos)
                        let errorLine = leadingSpaces + " | " + pipeSpaces + "`- error: \(error.message)\n"
                        markdown += errorLine
                        
                        // Notes (if any) - same positioning style
                        for note in error.notes {
                            let noteLine = leadingSpaces + " | " + pipeSpaces + "`- note: \(note.message)\n"
                            markdown += noteLine
                        }
                        
                        // Fix-its (if flag is set) - same positioning style
                        if showFixits, !error.fixIts.isEmpty {
                            for fixIt in error.fixIts {
                                // Use the properly escaped message from SyntaxFixIt instead of reconstructing
                                let fixitMsg = "fix-it: \(fixIt.message)"
                                let fixitLine = leadingSpaces + " | " + pipeSpaces + "`- " + fixitMsg + "\n"
                                markdown += fixitLine
                            }
                        }
                    }
                }
                markdown += "\n" // Add spacing between errors like swiftc
            }
        }
        
        return markdown
    }
    
    private func collectSwiftFiles(from paths: [String], recursive: Bool) throws -> [String] {
        var swiftFiles: [String] = []
        
        for path in paths {
            var isDirectory: ObjCBool = false
            
            if FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) {
                if isDirectory.boolValue {
                    if recursive {
                        let enumerator = FileManager.default.enumerator(atPath: path)
                        while let file = enumerator?.nextObject() as? String {
                            if file.hasSuffix(".swift") {
                                swiftFiles.append(URL(fileURLWithPath: path).appendingPathComponent(file).path)
                            }
                        }
                    } else {
                        let contents = try FileManager.default.contentsOfDirectory(atPath: path)
                        for file in contents {
                            if file.hasSuffix(".swift") {
                                swiftFiles.append(URL(fileURLWithPath: path).appendingPathComponent(file).path)
                            }
                        }
                    }
                } else if path.hasSuffix(".swift") {
                    swiftFiles.append(path)
                }
            } else {
                print("⚠️  Path not found: \(path)")
            }
        }
        
        return swiftFiles.sorted()
    }
}

// MARK: - JSON Data Models

struct ErrorSummary: Codable {
    let totalFilesAnalyzed: Int
    let filesWithErrors: Int
    let totalErrors: Int
    let files: [FileErrorReport]
}

struct FileErrorReport: Codable {
    let filePath: String
    let fileName: String
    let errorCount: Int
    let errors: [ErrorDetail]
    let analysisError: String?
    
    init(filePath: String, fileName: String, errorCount: Int, errors: [ErrorDetail], analysisError: String? = nil) {
        self.filePath = filePath
        self.fileName = fileName
        self.errorCount = errorCount
        self.errors = errors
        self.analysisError = analysisError
    }
}

struct ErrorDetail: Codable {
    let message: String
    let location: LocationInfo
    let sourceLineText: String
    let caretLineText: String
    let contextRange: String
    let sourceContext: [String]
    let fixIts: [FixItDetail]
    let notes: [NoteDetail]
    
    init(from syntaxError: SyntaxErrorDetail) {
        self.message = syntaxError.message
        self.location = LocationInfo(
            line: syntaxError.location.line,
            column: syntaxError.location.column,
            offset: syntaxError.location.offset
        )
        self.sourceLineText = syntaxError.sourceLineText
        self.caretLineText = syntaxError.caretLineText
        self.contextRange = syntaxError.contextRange
        self.sourceContext = syntaxError.sourceContext
        self.fixIts = syntaxError.fixIts.map { FixItDetail(from: $0) }
        self.notes = syntaxError.notes.map { NoteDetail(from: $0) }
    }
}

struct LocationInfo: Codable {
    let line: Int
    let column: Int
    let offset: Int
}

struct FixItDetail: Codable {
    let message: String
    let originalText: String
    let replacementText: String
    let location: LocationInfo
    
    init(from fixIt: SyntaxFixIt) {
        self.message = fixIt.message
        self.originalText = fixIt.originalText
        self.replacementText = fixIt.replacementText
        self.location = LocationInfo(
            line: fixIt.range.line,
            column: fixIt.range.column,
            offset: fixIt.range.offset
        )
    }
}

struct NoteDetail: Codable {
    let message: String
    let location: LocationInfo?
    let sourceLineText: String?
    
    init(from note: SyntaxNote) {
        self.message = note.message
        if let loc = note.location {
            self.location = LocationInfo(
                line: loc.line,
                column: loc.column,
                offset: loc.offset
            )
        } else {
            self.location = nil
        }
        self.sourceLineText = note.sourceLineText
    }
} 
