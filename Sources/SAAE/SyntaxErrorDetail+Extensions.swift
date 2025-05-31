import Foundation
import SwiftDiagnostics
import SwiftParser
import SwiftParserDiagnostics
import SwiftSyntax

extension SyntaxErrorDetail {
    /**
     Creates a SyntaxErrorDetail from a SwiftDiagnostics Diagnostic.
     
     This initializer implements the user's feedback:
     - Stores fullSourceText as lines for fast access
     - Uses SourceLocationConverter for line content extraction
     - Handles edge cases with bounds checking
     - Generates visual caret indicators
     
     - Parameters:
       - diagnostic: The diagnostic from SwiftParserDiagnostics
       - sourceLines: Pre-split source code lines for efficient access
       - converter: SourceLocationConverter for position mapping
     */
    public init(from diagnostic: Diagnostic, sourceLines: [String], converter: SourceLocationConverter) {
        // Basic diagnostic information
        self.message = diagnostic.message
        
        // Use direct byte offset for more accurate positioning
        let byteOffset = diagnostic.position
        let computedLocation = converter.location(for: byteOffset)
        
        // Apply heuristics to improve error positioning for better UX
        // computedLocation = Self.improveErrorPositioning(
        //     originalLocation: computedLocation,
        //     message: diagnostic.message,
        //     sourceLines: sourceLines
        // )
        
        self.location = computedLocation
        self.affectedNode = diagnostic.node
        
        // Extract source line text with bounds checking
        let lineIndex = self.location.line - 1 // Convert to 0-based index
        if lineIndex >= 0 && lineIndex < sourceLines.count {
            self.sourceLineText = sourceLines[lineIndex]
        } else {
            self.sourceLineText = "" // Edge case: invalid line number
        }
        
        // Generate visual caret line (e.g., "    ^")
        let caretPosition = max(0, self.location.column - 1) // Convert to 0-based, ensure non-negative
        self.caretLineText = String(repeating: " ", count: caretPosition) + "^"
        
        // Extract source context (lines around the error)
        let contextRadius = 1 // Show 1 line above and below
        let startLine = max(0, lineIndex - contextRadius)
        let endLine = min(sourceLines.count - 1, lineIndex + contextRadius)
        
        var contextLines: [String] = []
        // Ensure startLine <= endLine to avoid range errors
        if startLine <= endLine && endLine < sourceLines.count {
            for i in startLine...endLine {
                contextLines.append(sourceLines[i])
            }
        } else if lineIndex >= 0 && lineIndex < sourceLines.count {
            // Fallback: just include the error line itself
            contextLines.append(sourceLines[lineIndex])
        }
        self.sourceContext = contextLines
        
        // Calculate range string based on actual context lines used
        if contextLines.isEmpty {
            self.contextRange = "0-0" // No valid context
        } else if contextLines.count == 1 {
            self.contextRange = "\(lineIndex + 1)" // Just the error line
        } else {
            self.contextRange = "\(startLine + 1)-\(endLine + 1)" // Convert back to 1-based for display
        }
        
        // Process fix-its with SourceLocationConverter
        var fixIts: [SyntaxFixIt] = []
        for fixIt in diagnostic.fixIts {
            // Process all changes for this fix-it together to create a single logical fix-it
            let combinedFixIt = Self.processCombinedFixIt(fixIt, converter: converter, fallbackLocation: self.location)
            if let fix = combinedFixIt {
                fixIts.append(fix)
            }
        }
        self.fixIts = fixIts
        
        // Process notes
        var notes: [SyntaxNote] = []
        for note in diagnostic.notes {
            let noteLocation = converter.location(for: note.node.position)
            
            // Extract source line for the note with bounds checking
            let noteLineIndex = noteLocation.line - 1
            let noteSourceLine: String?
            if noteLineIndex >= 0 && noteLineIndex < sourceLines.count {
                noteSourceLine = sourceLines[noteLineIndex]
            } else {
                noteSourceLine = nil // Edge case: invalid line number
            }
            
            let syntaxNote = SyntaxNote(
                message: note.message,
                location: noteLocation,
                sourceLineText: noteSourceLine
            )
            notes.append(syntaxNote)
        }
        self.notes = notes
    }
    
    /// Processes a combined fix-it from multiple changes
    internal static func processCombinedFixIt(_ fixIt: FixIt, converter: SourceLocationConverter, fallbackLocation: SourceLocation) -> SyntaxFixIt? {
        var insertions: [String] = []
        var removals: [String] = []
        var replacements: [(String, String)] = []
        var primaryLocation: SourceLocation = fallbackLocation
        var hasValidChanges = false
        
        // Process all changes and categorize them
        for change in fixIt.changes {
            switch change {
            case .replace(let oldNode, let newNode):
                let location = converter.location(for: oldNode.position)
                let originalText = oldNode.description
                let replacementText = newNode.description
                
                // Use the first valid location as primary
                if !hasValidChanges {
                    primaryLocation = location
                    hasValidChanges = true
                }
                
                if originalText.isEmpty && !replacementText.isEmpty {
                    // This is an insertion
                    insertions.append(replacementText)
                } else if !originalText.isEmpty && replacementText.isEmpty {
                    // This is a removal
                    removals.append(originalText)
                } else if !originalText.isEmpty && !replacementText.isEmpty {
                    // This is a replacement
                    replacements.append((originalText, replacementText))
                }
                
            case .replaceLeadingTrivia(let token, let newTrivia):
                let location = converter.location(for: token.position)
                let originalText = token.leadingTrivia.description
                let replacementText = newTrivia.description
                
                // Skip meaningless trivia changes
                if originalText.isEmpty && replacementText.isEmpty {
                    continue
                }
                
                if !hasValidChanges {
                    primaryLocation = location
                    hasValidChanges = true
                }
                
                if originalText.isEmpty && !replacementText.isEmpty {
                    insertions.append(replacementText)
                } else if !originalText.isEmpty && replacementText.isEmpty {
                    removals.append(originalText)
                } else if !originalText.isEmpty && !replacementText.isEmpty {
                    replacements.append((originalText, replacementText))
                }
                
            case .replaceTrailingTrivia(let token, let newTrivia):
                let location = converter.location(for: token.endPositionBeforeTrailingTrivia)
                let originalText = token.trailingTrivia.description
                let replacementText = newTrivia.description
                
                // Skip meaningless trivia changes
                if originalText.isEmpty && replacementText.isEmpty {
                    continue
                }
                
                if !hasValidChanges {
                    primaryLocation = location
                    hasValidChanges = true
                }
                
                if originalText.isEmpty && !replacementText.isEmpty {
                    insertions.append(replacementText)
                } else if !originalText.isEmpty && replacementText.isEmpty {
                    removals.append(originalText)
                } else if !originalText.isEmpty && !replacementText.isEmpty {
                    replacements.append((originalText, replacementText))
                }
                
            @unknown default:
                // For unknown change types, create a generic fix-it
                if !hasValidChanges {
                    hasValidChanges = true
                }
            }
        }
        
        // If no valid changes were found, return nil
        guard hasValidChanges else { return nil }
        
        // Generate a combined message based on the changes
        let message = generateCombinedFixItMessage(
            insertions: insertions,
            removals: removals,
            replacements: replacements
        )
        
        // For the combined fix-it, we'll use the concatenated insertions as replacementText
        // and empty string as originalText (since it's a composite operation)
        let combinedReplacementText = insertions.joined(separator: "")
        
        return SyntaxFixIt(
            message: message,
            originalText: "",
            replacementText: combinedReplacementText,
            range: primaryLocation
        )
    }
    
    /// Generates a human-readable message for combined fix-it operations
    internal static func generateCombinedFixItMessage(
        insertions: [String],
        removals: [String],
        replacements: [(String, String)]
    ) -> String {
        var messageParts: [String] = []
        
        // Handle insertions
        if !insertions.isEmpty {
            let escapedInsertions = insertions.map { escapeForDisplay($0) }
            if insertions.count == 1 {
                messageParts.append("insert `\(escapedInsertions[0])`")
            } else {
                let combined = escapedInsertions.joined(separator: "")
                messageParts.append("insert `\(combined)`")
            }
        }
        
        // Handle removals
        if !removals.isEmpty {
            let escapedRemovals = removals.map { escapeForDisplay($0) }
            if removals.count == 1 {
                messageParts.append("remove `\(escapedRemovals[0])`")
            } else {
                messageParts.append("remove `\(escapedRemovals.joined(separator: ", "))`")
            }
        }
        
        // Handle replacements
        for (original, replacement) in replacements {
            let escapedOrig = escapeForDisplay(original)
            let escapedRepl = escapeForDisplay(replacement)
            messageParts.append("replace `\(escapedOrig)` with `\(escapedRepl)`")
        }
        
        // Combine all parts
        if messageParts.isEmpty {
            return "fix syntax error"
        } else if messageParts.count == 1 {
            return messageParts[0]
        } else {
            return messageParts.joined(separator: " and ")
        }
    }
    
    /// Escapes special characters in text for readable display in fix-it messages
    internal static func escapeForDisplay(_ text: String) -> String {
        var result = text
        
        // Escape all types of whitespace and special characters
        // Order matters: escape compound sequences first
        result = result.replacingOccurrences(of: "\\", with: "\\\\") // Escape backslashes first
        result = result.replacingOccurrences(of: "\r\n", with: "\\r\\n") // Handle Windows line endings first
        result = result.replacingOccurrences(of: "\n", with: "\\n")
        result = result.replacingOccurrences(of: "\r", with: "\\r") 
        result = result.replacingOccurrences(of: "\t", with: "\\t")
        result = result.replacingOccurrences(of: "\u{000B}", with: "\\v") // Vertical tab
        result = result.replacingOccurrences(of: "\u{000C}", with: "\\f") // Form feed
        
        return result
    }
    
    /// Applies heuristics to improve error positioning for better UX
    internal static func improveErrorPositioning(originalLocation: SourceLocation, message: String, sourceLines: [String]) -> SourceLocation {
        // General heuristic: "unexpected code 'XXXX' ..." errors are often mispositioned by SwiftSyntax
        // They should point to where the quoted code actually appears, not where SwiftSyntax thinks it should be reported
        if message.contains("unexpected code") {
            return adjustUnexpectedCodeError(originalLocation: originalLocation, sourceLines: sourceLines, message: message)
        }
        
        // Add more heuristics here as needed in the future
        
        return originalLocation
    }
    
    /// Adjusts error position for "unexpected code 'XXXX' ..." errors that are misplaced by SwiftSyntax
    internal static func adjustUnexpectedCodeError(originalLocation: SourceLocation, sourceLines: [String], message: String) -> SourceLocation {
        let currentLineIndex = originalLocation.line - 1 // Convert to 0-based
        
        // Extract the problematic code from the error message
        // Pattern: "unexpected code 'XXXXX' ..."
        var problematicCode: String? = nil
        
        if let startQuote = message.range(of: "'"),
           let endQuote = message.range(of: "'", range: startQuote.upperBound..<message.endIndex) {
            problematicCode = String(message[startQuote.upperBound..<endQuote.lowerBound])
        }
        
        // If we can't extract specific code, return original location
        guard let code = problematicCode else {
            return originalLocation
        }
        
        // First check the current line where the error is reported
        if currentLineIndex < sourceLines.count {
            let currentLine = sourceLines[currentLineIndex]
            
            if currentLine.contains(code) {
                // Find the position of the problematic code in the line
                guard let codeRange = currentLine.range(of: code) else {
                    // Fallback to start of non-whitespace content
                    let column = currentLine.firstIndex(where: { !$0.isWhitespace }).map { 
                        currentLine.distance(from: currentLine.startIndex, to: $0) + 1 
                    } ?? 1
                    
                    return SourceLocation(
                        line: currentLineIndex + 1, // Convert back to 1-based
                        column: column,
                        offset: originalLocation.offset,
                        file: originalLocation.file
                    )
                }
                
                let column = currentLine.distance(from: currentLine.startIndex, to: codeRange.lowerBound) + 1
                
                return SourceLocation(
                    line: currentLineIndex + 1, // Convert back to 1-based
                    column: column,
                    offset: originalLocation.offset,
                    file: originalLocation.file
                )
            }
        }
        
        // Then search backwards if not found on current line
        // Look backwards from current position to find the line containing the problematic code
        var searchLineIndex = currentLineIndex - 1
        let maxSearchLines = 5 // Search a reasonable distance back
        
        while searchLineIndex >= 0 && (currentLineIndex - searchLineIndex) <= maxSearchLines {
            guard searchLineIndex < sourceLines.count else { break }
            
            let originalLine = sourceLines[searchLineIndex]
            
            // Check if this line contains the problematic code mentioned in the error
            if originalLine.contains(code) {
                // Find the position of the problematic code in the line
                guard let codeRange = originalLine.range(of: code) else {
                    // Fallback to start of non-whitespace content
                    let column = originalLine.firstIndex(where: { !$0.isWhitespace }).map { 
                        originalLine.distance(from: originalLine.startIndex, to: $0) + 1 
                    } ?? 1
                    
                    return SourceLocation(
                        line: searchLineIndex + 1, // Convert back to 1-based
                        column: column,
                        offset: originalLocation.offset,
                        file: originalLocation.file
                    )
                }
                
                let column = originalLine.distance(from: originalLine.startIndex, to: codeRange.lowerBound) + 1
                
                return SourceLocation(
                    line: searchLineIndex + 1, // Convert back to 1-based
                    column: column,
                    offset: originalLocation.offset,
                    file: originalLocation.file
                )
            }
            
            searchLineIndex -= 1
        }
        
        // If no problematic code found, return original location
        return originalLocation
    }
}
