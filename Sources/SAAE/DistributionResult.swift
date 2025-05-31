import Foundation
import SwiftSyntax

/// Result of code distribution operation
public struct DistributionResult {
    /// The modified original file with extracted declarations removed
    public let modifiedOriginalFile: GeneratedFile?
    
    /// New files created for the extracted declarations
    public let newFiles: [GeneratedFile]
    
    public init(modifiedOriginalFile: GeneratedFile?, newFiles: [GeneratedFile]) {
        self.modifiedOriginalFile = modifiedOriginalFile
        self.newFiles = newFiles
    }
}
