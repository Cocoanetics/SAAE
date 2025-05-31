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
        
        let result = try distributor.distributeKeepingFirst(tree: tree, originalFileName: "TestFile.swift")
        
        // All type declarations are extracted to separate files
        #expect(result.newFiles.count == 5)
        
        // Original file should be nil since all declarations are types
        #expect(result.modifiedOriginalFile == nil)
        
        // Verify new files are created with correct names and content
        let filesByName: [String: GeneratedFile] = Dictionary(uniqueKeysWithValues: result.newFiles.map { ($0.fileName, $0) })
        
        // Check MainModel.swift
        let mainModelFile = try #require(filesByName["MainModel.swift"])
        #expect(mainModelFile.content.contains("struct MainModel"))
        #expect(mainModelFile.content.contains("import Foundation"))
        #expect(mainModelFile.content.contains("import SwiftUI"))
        
        // Check UtilityHelper.swift
        let utilityFile = try #require(filesByName["UtilityHelper.swift"])
        #expect(utilityFile.content.contains("class UtilityHelper"))
        #expect(utilityFile.content.contains("import Foundation"))
        #expect(utilityFile.content.contains("import SwiftUI"))
        
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
        
//        // Print original source and all resulting files
//        print("\n=== Original Source ===\n" + sourceCode)
//        if let original = result.modifiedOriginalFile {
//            print("\n=== File: \(original.fileName) ===\n" + original.content)
//        }
//        for file in result.newFiles {
//            print("\n=== File: \(file.fileName) ===\n" + file.content)
//        }
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
        
        let result = try distributor.distributeKeepingFirst(tree: tree, originalFileName: "TestFile.swift")
        
        // Both struct and extension are extracted to separate files
        #expect(result.newFiles.count == 2)
        #expect(result.modifiedOriginalFile == nil)
        
        let filesByName: [String: GeneratedFile] = Dictionary(uniqueKeysWithValues: result.newFiles.map { ($0.fileName, $0) })
        
        // Check DataModel.swift (the struct)
        let structFile = try #require(filesByName["DataModel.swift"])
        #expect(structFile.content.contains("struct DataModel"))
        #expect(structFile.content.contains("import Foundation"))
        
        // Check DataModel+Extensions.swift (the extension)
        let extensionFile = try #require(filesByName["DataModel+Extensions.swift"])
        #expect(extensionFile.content.contains("extension DataModel"))
        #expect(extensionFile.content.contains("import Foundation"))
        
//        // Print original source and all resulting files
//        print("\n=== Original Source ===\n" + sourceCode)
//        if let original = result.modifiedOriginalFile {
//            print("\n=== File: \(original.fileName) ===\n" + original.content)
//        }
//        for file in result.newFiles {
//            print("\n=== File: \(file.fileName) ===\n" + file.content)
//        }
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
        
        let result = try distributor.distributeKeepingFirst(tree: tree, originalFileName: "TestFile.swift")
        
        // Single type declaration should be extracted to separate file
        #expect(result.modifiedOriginalFile == nil)
        #expect(result.newFiles.count == 1)
        
        let singleFile = result.newFiles[0]
        #expect(singleFile.fileName == "SingleModel.swift")
        #expect(singleFile.content.contains("struct SingleModel"))
        #expect(singleFile.content.contains("import Foundation"))
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
        
        let result = try distributor.distributeKeepingFirst(tree: tree, originalFileName: "TestFile.swift")
        
        // Type declarations (class, actor, protocol) are extracted, typealias stays in original
        #expect(result.newFiles.count == 3)
        #expect(result.modifiedOriginalFile != nil)
        
        let filesByName: [String: GeneratedFile] = Dictionary(uniqueKeysWithValues: result.newFiles.map { ($0.fileName, $0) })
        
        #expect(filesByName["PrimaryClass.swift"] != nil)
        #expect(filesByName["DataProcessor.swift"] != nil)
        #expect(filesByName["ServiceProtocol.swift"] != nil)
        
        // Verify actor file content
        let actorFile = try #require(filesByName["DataProcessor.swift"])
        #expect(actorFile.content.contains("actor DataProcessor"))
        
        // Verify typealias stays in original file
        let originalContent = result.modifiedOriginalFile!.content
        #expect(originalContent.contains("typealias StringMap"))
        #expect(originalContent.contains("import Foundation"))
    }
} 
