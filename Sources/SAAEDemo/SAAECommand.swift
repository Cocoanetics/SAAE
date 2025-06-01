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
        subcommands: [AnalyzeCommand.self, ErrorsCommand.self, DistributeCommand.self, ReindentCommand.self],
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
                    let prefix = String(format: "%*d ┃ ", lineNumberWidth, lineNumber)
                    markdown += prefix + line + "\n"
                    if isErrorLine {
// Collect all pointer lines (error, notes, fix-its)
                        var pointerLines: [(String, String)] = [("error", error.message)]
                        for note in error.notes {
                            var noteMsg = note.message
                            if let loc = note.location {
                                noteMsg += " (line: \(loc.line), column: \(loc.column))"
                            }
                            pointerLines.append(("note", noteMsg))
                        }
                        if showFixits, !error.fixIts.isEmpty {
                            for fixIt in error.fixIts {
                                pointerLines.append(("fix-it", fixIt.message))
                            }
                        }
                        let pointerCount = pointerLines.count
                        let errorColumnPos = max(0, error.location.column - 1)
                        let leadingSpaces = String(repeating: " ", count: lineNumberWidth)
                        let pipeSpaces = String(repeating: " ", count: errorColumnPos)
                        for (i, (kind, msg)) in pointerLines.enumerated() {
                            let isLast = (i == pointerCount - 1)
                            let branch = isLast ? "┗" : "┣"
                            let pointerLine = leadingSpaces + " ┃ " + pipeSpaces + branch + "━━ " + (kind == "error" ? "error: " : kind == "note" ? "note: " : "fix-it: ") + msg + "\n"
                            markdown += pointerLine
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

// MARK: - Distribute Subcommand (Code Distribution Feature)

struct DistributeCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "distribute",
        abstract: "Split Swift files into separate files for each top-level declaration, preserving imports.",
        discussion: """
  For each input file, splits all top-level declarations into separate files (e.g., Type.swift, Type+Protocol.swift), preserving import statements. 
  If a directory is given, all .swift files are processed (recursively if -r is set).
  By default, writes to an output directory (or prints to stdout if not specified).
  
  Examples:
    SAAEDemo distribute MyFile.swift
    SAAEDemo distribute Sources/ --recursive -o SplitSources
    SAAEDemo distribute file1.swift file2.swift -o out
"""
    )

    @Argument(help: "Swift file(s) or directory to split")
    var paths: [String]

    @Flag(name: .shortAndLong, help: "Recursively search directories for Swift files")
    var recursive: Bool = false

    @Option(name: .shortAndLong, help: "Output directory (default: print to stdout)")
    var output: String?

    @Flag(name: .long, help: "Show what would be written, but do not write any files")
    var dryRun: Bool = false

    func run() async throws {
        let swiftFiles = try collectSwiftFiles(from: paths, recursive: recursive)
        guard !swiftFiles.isEmpty else {
        print("❌ No Swift files found in the specified paths.")
        throw ExitCode.failure
    }
        print("📁 Found \(swiftFiles.count) Swift file(s) to distribute...")
        let outputDir: URL? = output.map { URL(fileURLWithPath: $0) }
        if let dir = outputDir {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        }
        if dryRun {
            var outputBuffer = ""
            let filesByFolder = Dictionary(grouping: swiftFiles) { filePath in
            URL(fileURLWithPath: filePath).deletingLastPathComponent().path
        }
            for (folder, files) in filesByFolder.sorted(by: { $0.key < $1.key }) {
                outputBuffer += "\n📂 \(folder)\n"
                var outputLines: [(isEdit: Bool, name: String, info: String)] = []
                for filePath in files.sorted() {
                    let url = URL(fileURLWithPath: filePath)
                    let source = try String(contentsOf: url)
                    let tree = try SyntaxTree(string: source)
                    let distributor = CodeDistributor()
                    let result = try distributor.distributeKeepingFirst(tree: tree, originalFileName: url.lastPathComponent)
                    let targetDir: URL = outputDir ?? url.deletingLastPathComponent()
                    let origPath = targetDir.appendingPathComponent(result.modifiedOriginalFile?.fileName ?? "(none)").lastPathComponent
                    if let original = result.modifiedOriginalFile {
                        let oldLineCount = source.split(separator: "\n").count
                        let newLineCount = original.content.split(separator: "\n").count
                        let deltaStr = "→\(newLineCount)"
                        outputLines.append((true, origPath, "[\(oldLineCount)\(deltaStr)]"))
                    }
                    for file in result.newFiles {
                        let filePath = targetDir.appendingPathComponent(file.fileName).lastPathComponent
                        let lineCount = file.content.split(separator: "\n").count
                        outputLines.append((false, filePath, "[\(lineCount)]"))
                    }
                }
                for i in 0..<outputLines.count {
                    let (isEdit, name, info) = outputLines[i]
                    let isLast = i == outputLines.count - 1
                    let branch = isLast ? "└─" : "├─"
                    let icon = isEdit ? "✏️" : "🆕"
                    outputBuffer += "  \(branch) \(icon)  \(name) \(info)\n"
                }
            }
            outputBuffer += "\n\u{2705} Distribution complete.\n"
            print(compressEmptyLines(outputBuffer))
            return
        }
        for (fileIdx, filePath) in swiftFiles.enumerated() {
            let url = URL(fileURLWithPath: filePath)
            print("\n=== Processing: \(filePath) ===")
            let source = try String(contentsOf: url)
            let tree = try SyntaxTree(string: source)
            let distributor = CodeDistributor()
            let result = try distributor.distributeKeepingFirst(tree: tree, originalFileName: url.lastPathComponent)
            let targetDir: URL = outputDir ?? url.deletingLastPathComponent()
            if dryRun {
                let origPath = targetDir.appendingPathComponent(result.modifiedOriginalFile?.fileName ?? "(none)").lastPathComponent
                if let original = result.modifiedOriginalFile {
                    let oldLineCount = source.split(separator: "\n").count
                    let newLineCount = original.content.split(separator: "\n").count
                    let deltaStr = "→\(newLineCount)"
                    let hasChildren = !result.newFiles.isEmpty
                    let isLastFile = fileIdx == swiftFiles.count - 1
                    let branch = hasChildren ? (isLastFile ? "└─" : "├─") : (isLastFile ? "└─" : "├─")
                    print("  \(branch) ✏️  \(origPath) [\(oldLineCount)\(deltaStr)]")
                    if hasChildren {
                        let newFiles = result.newFiles
                        for (i, file) in newFiles.enumerated() {
                            let filePath = targetDir.appendingPathComponent(file.fileName).lastPathComponent
                            let lineCount = file.content.split(separator: "\n").count
                            let isLast = (i == newFiles.count - 1)
                            let childBranch = isLastFile ? "    " : "│   "
                            let childBranchSymbol = isLast ? "└─" : "├─"
                            print("  \(childBranch)\(childBranchSymbol) 🆕  \(filePath) [\(lineCount)]")
                        }
                    }
                }
            } else {
// Write original file (overwrite)
                if let original = result.modifiedOriginalFile {
                    let originalPath = url // existing file path
                    let newPath = targetDir.appendingPathComponent(original.fileName)
                    let contentWithNewline = ensureEndsWithNewline(original.content)
                    try contentWithNewline.write(to: newPath, atomically: true, encoding: .utf8)
                    print("  → Wrote \(original.fileName)")
// If the filename changed, delete the old file to complete the rename
                    if originalPath.lastPathComponent != original.fileName {
                        try? FileManager.default.removeItem(at: originalPath)
                        print("  ⨂ Deleted old file \(originalPath.lastPathComponent)")
                    }
                }
// Write new files
                for file in result.newFiles {
                    let outPath = targetDir.appendingPathComponent(file.fileName)
                    let contentWithNewline = ensureEndsWithNewline(file.content)
                    try contentWithNewline.write(to: outPath, atomically: true, encoding: .utf8)
                    print("  → Wrote \(file.fileName)")
                }
            }
        }
        print("\n✅ Distribution complete.")
    }

/// Extracts a summary of top-level declarations from file content for dry-run output
    private func describeDeclarations(in content: String) -> String {
// Simple regex to match top-level declarations (struct, class, enum, extension, protocol, typealias, actor)
        let pattern = "^(public |internal |private |fileprivate |open )?(struct|class|enum|extension|protocol|typealias|actor)\\s+([A-Za-z0-9_+]+)" // + for extensions
        let lines = content.split(separator: "\n")
        var decls: [String] = []
        for line in lines {
            if let match = line.range(of: pattern, options: [.regularExpression, .anchored]) {
                let decl = String(line[match])
                decls.append(decl.trimmingCharacters(in: .whitespaces))
            }
        }
        return decls.joined(separator: ", ")
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

    func compressEmptyLines(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        var result: [String] = []
        var lastWasEmpty = false
        for line in lines {
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                if !lastWasEmpty {
                    result.append("")
                    lastWasEmpty = true
                }
            } else {
                result.append(line)
                lastWasEmpty = false
            }
        }
        return result.joined(separator: "\n")
    }

/// Ensures content ends with a newline character
    private func ensureEndsWithNewline(_ content: String) -> String {
        return content.hasSuffix("\n") ? content : content + "\n"
    }

// MARK: - Conflict Detection
/// Returns true if any file in the distribution result would overwrite an
/// existing file that is *not* the original file we are processing.
    private func hasFileConflicts(result: DistributionResult, originalURL: URL, targetDir: URL) -> Bool {
        var conflicts: [String] = []
        let fm = FileManager.default
// Helper to check path
        func pathExists(_ fileName: String) -> Bool {
            fm.fileExists(atPath: targetDir.appendingPathComponent(fileName).path)
        }
// Check modified original file (renamed)
        if let original = result.modifiedOriginalFile {
            let newName = original.fileName
            if newName != originalURL.lastPathComponent && pathExists(newName) {
                conflicts.append(newName)
            }
        }
// Check new files
        for file in result.newFiles {
            if pathExists(file.fileName) {
                conflicts.append(file.fileName)
            }
        }
        if !conflicts.isEmpty {
            print("⚠️  File conflict(s) detected: \(conflicts.joined(separator: ", "))")
        }
        return !conflicts.isEmpty
    }
}

// MARK: - Reindent Subcommand (Indentation Fixing Feature)

struct ReindentCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "reindent",
        abstract: "Fix indentation in Swift source files by reindenting them with consistent spacing",
        discussion: """
  Reindent Swift source files in place with consistent indentation. This command processes files or directories
  and applies proper indentation with configurable spacing, including special handling for switch statements
  where case labels are indented deeper than the switch itself.
  
  Examples:
    SAAEDemo reindent MyFile.swift                         # Reindent single file with 4-space indentation
    SAAEDemo reindent MyFile.swift --indent-size 2         # Use 2-space indentation
    SAAEDemo reindent Sources/ --recursive                 # Reindent all Swift files in Sources recursively
    SAAEDemo reindent file1.swift file2.swift --dry-run   # Show what would be changed without modifying files
    SAAEDemo reindent Sources/ -r -s 2                     # Short form: recursive with 2-space indentation
"""
    )

    @Argument(help: "Swift file(s) or directory to reindent")
    var paths: [String]

    @Flag(name: .shortAndLong, help: "Recursively search directories for Swift files")
    var recursive: Bool = false

    @Option(name: .shortAndLong, help: "Number of spaces per indentation level")
    var indentSize: Int = 4

    @Flag(help: "Show what would be changed without modifying files")
    var dryRun: Bool = false

    func run() async throws {
        print("🔧 SAAE Indentation Fixer")
        print("=========================\n")

        guard indentSize > 0 && indentSize <= 16 else {
        print("❌ Invalid indent size: \(indentSize). Must be between 1 and 16.")
        throw ExitCode.failure
    }

        let swiftFiles = try collectSwiftFiles(from: paths, recursive: recursive)

        if swiftFiles.isEmpty {
            print("❌ No Swift files found in the specified paths.")
            throw ExitCode.failure
        }

        print("📁 Found \(swiftFiles.count) Swift file(s) to reindent...")
        print("🔧 Using \(indentSize)-space indentation")

        if dryRun {
            print("🔍 Dry run mode - no files will be modified\n")
        } else {
            print("⚠️  Files will be modified in place\n")
        }

        var filesModified = 0
        var totalFiles = 0

        for filePath in swiftFiles {
            totalFiles += 1
            let url = URL(fileURLWithPath: filePath)

            do {
            let originalContent = try String(contentsOf: url)
            let tree = try SyntaxTree(string: originalContent)
            let reindentedTree = try tree.reindent(indentSize: indentSize)
            let newContent = reindentedTree.serializeToCode()

            if originalContent != newContent {
                filesModified += 1

                if dryRun {
                    print("📝 \(filePath): Would be modified")
// Optionally show a brief diff summary
                    let originalLines = originalContent.components(separatedBy: .newlines).count
                    let newLines = newContent.components(separatedBy: .newlines).count
                    print("   Lines: \(originalLines) → \(newLines)")
                } else {
                    try newContent.write(to: url, atomically: true, encoding: .utf8)
                    print("✅ \(filePath): Reindented")
                }
            } else {
                print("⏭️  \(filePath): Already properly indented")
            }

        } catch {
            print("❌ \(filePath): Failed to process - \(error)")
        }
        }

        if dryRun {
            print("\n📊 Summary (Dry Run):")
            print("   Files analyzed: \(totalFiles)")
            print("   Files that would be modified: \(filesModified)")
            print("   Files already correct: \(totalFiles - filesModified)")
        } else {
            print("\n📊 Summary:")
            print("   Files processed: \(totalFiles)")
            print("   Files modified: \(filesModified)")
            print("   Files already correct: \(totalFiles - filesModified)")
        }

        if filesModified > 0 {
            if dryRun {
                print("\n🔍 Run without --dry-run to apply these changes.")
            } else {
                print("\n✅ Indentation fixing complete!")
            }
        } else {
            print("\n✅ All files already have correct indentation!")
        }
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
