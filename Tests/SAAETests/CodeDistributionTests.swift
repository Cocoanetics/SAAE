import Testing
import Foundation
@testable import SAAE

@Suite("Phase 4: Code Distribution Tests")
struct Phase4_CodeDistributionTests {
    
    @Test("Distribute declarations keeping first, moving others to separate files")
    func distributeDeclarations_keepFirstMoveOthers() throws {
        let sourceCode = """
        import Foundation
        import SwiftUI
        
        /// The main data model
        public struct MainModel {
            public let id: UUID
            public let name: String
        }
        
        /// Helper utility class
        public class UtilityHelper {
            public func process() {}
        }
        
        /// Configuration enum
        public enum Configuration {
            case debug
            case release
        }
        
        /// Extension for Codable conformance
        extension MainModel: Codable {
            // Codable implementation
        }
        
        /// Extension for Equatable conformance  
        extension UtilityHelper: Equatable {
            public static func == (lhs: UtilityHelper, rhs: UtilityHelper) -> Bool {
                return true
            }
        }
        """
        
        let tree = try SyntaxTree(string: sourceCode)
        let distributor = CodeDistributor()
        
        let result = try distributor.distributeKeepingFirst(tree: tree)
        
        // Verify we have the expected number of files
        #expect(result.originalFile != nil)
        #expect(result.newFiles.count == 4)
        
        // Verify original file keeps only the first declaration (MainModel)
        let originalContent = result.originalFile!.content
        #expect(originalContent.contains("struct MainModel"))
        #expect(!originalContent.contains("class UtilityHelper"))
        #expect(!originalContent.contains("enum Configuration"))
        #expect(!originalContent.contains("extension MainModel"))
        #expect(!originalContent.contains("extension UtilityHelper"))
        
        // Verify imports are preserved in original
        #expect(originalContent.contains("import Foundation"))
        #expect(originalContent.contains("import SwiftUI"))
        
        // Verify new files are created with correct names and content
        let filesByName: [String: GeneratedFile] = Dictionary(uniqueKeysWithValues: result.newFiles.map { ($0.fileName, $0) })
        
        // Check UtilityHelper.swift
        let utilityFile = try #require(filesByName["UtilityHelper.swift"])
        #expect(utilityFile.content.contains("class UtilityHelper"))
        #expect(utilityFile.content.contains("import Foundation"))
        #expect(utilityFile.content.contains("import SwiftUI"))
        #expect(!utilityFile.content.contains("struct MainModel"))
        
        // Check Configuration.swift
        let configFile = try #require(filesByName["Configuration.swift"])
        #expect(configFile.content.contains("enum Configuration"))
        #expect(configFile.content.contains("import Foundation"))
        #expect(configFile.content.contains("import SwiftUI"))
        
        // Check MainModel+Codable.swift (extension with protocol)
        let codableExtFile = try #require(filesByName["MainModel+Codable.swift"])
        #expect(codableExtFile.content.contains("extension MainModel: Codable"))
        #expect(codableExtFile.content.contains("import Foundation"))
        #expect(codableExtFile.content.contains("import SwiftUI"))
        
        // Check UtilityHelper+Equatable.swift (extension with protocol)
        let equatableExtFile = try #require(filesByName["UtilityHelper+Equatable.swift"])
        #expect(equatableExtFile.content.contains("extension UtilityHelper: Equatable"))
        #expect(equatableExtFile.content.contains("import Foundation"))
        #expect(equatableExtFile.content.contains("import SwiftUI"))
    }
    
    @Test("Handle extension without protocol conformance")
    func distributeDeclarations_extensionWithoutProtocol() throws {
        let sourceCode = """
        import Foundation
        
        public struct DataModel {
            public let value: String
        }
        
        /// Extension with additional functionality
        extension DataModel {
            public func formatted() -> String {
                return "Formatted: \\(value)"
            }
        }
        """
        
        let tree = try SyntaxTree(string: sourceCode)
        let distributor = CodeDistributor()
        
        let result = try distributor.distributeKeepingFirst(tree: tree)
        
        #expect(result.newFiles.count == 1)
        
        let extensionFile = result.newFiles[0]
        #expect(extensionFile.fileName == "DataModel+Extensions.swift")
        #expect(extensionFile.content.contains("extension DataModel"))
        #expect(extensionFile.content.contains("import Foundation"))
    }
    
    @Test("Handle file with only one declaration")
    func distributeDeclarations_singleDeclaration() throws {
        let sourceCode = """
        import Foundation
        
        public struct SingleModel {
            public let id: UUID
        }
        """
        
        let tree = try SyntaxTree(string: sourceCode)
        let distributor = CodeDistributor()
        
        let result = try distributor.distributeKeepingFirst(tree: tree)
        
        // Should keep the single declaration in original file
        #expect(result.originalFile != nil)
        #expect(result.newFiles.isEmpty)
        #expect(result.originalFile!.content.contains("struct SingleModel"))
        #expect(result.originalFile!.content.contains("import Foundation"))
    }
    
    @Test("Handle actors and other declaration types")
    func distributeDeclarations_variousTypes() throws {
        let sourceCode = """
        import Foundation
        
        public class PrimaryClass {
            public let name: String = ""
        }
        
        public actor DataProcessor {
            public func process() async {}
        }
        
        public protocol ServiceProtocol {
            func serve()
        }
        
        public typealias StringMap = [String: String]
        """
        
        let tree = try SyntaxTree(string: sourceCode)
        let distributor = CodeDistributor()
        
        let result = try distributor.distributeKeepingFirst(tree: tree)
        
        #expect(result.newFiles.count == 3)
        
        let filesByName: [String: GeneratedFile] = Dictionary(uniqueKeysWithValues: result.newFiles.map { ($0.fileName, $0) })
        
        #expect(filesByName["DataProcessor.swift"] != nil)
        #expect(filesByName["ServiceProtocol.swift"] != nil)
        #expect(filesByName["StringMap.swift"] != nil)
        
        // Verify actor file content
        let actorFile = try #require(filesByName["DataProcessor.swift"])
        #expect(actorFile.content.contains("actor DataProcessor"))
    }
} 