import Foundation

/// Represents the complete overview of a Swift file including imports and declarations
internal struct CodeOverview: Codable {
    internal let imports: [String]
    internal let declarations: [DeclarationOverview]
    
    internal init(imports: [String], declarations: [DeclarationOverview]) {
        self.imports = imports
        self.declarations = declarations
    }
}

/// Represents a single file's overview with its path for multi-file output
internal struct FileOverview: Codable {
    internal let path: String
    internal let imports: [String]
    internal let declarations: [DeclarationOverview]
    
    internal init(path: String, imports: [String], declarations: [DeclarationOverview]) {
        self.path = path
        self.imports = imports
        self.declarations = declarations
    }
}

/// Represents the overview of multiple Swift files
internal struct MultiFileCodeOverview: Codable {
    internal let files: [FileOverview]
    
    internal init(files: [FileOverview]) {
        self.files = files
    }
}

/// Represents a declaration in the overview
internal struct DeclarationOverview: Codable {
    internal let path: String
    internal let type: String
    internal let name: String
    internal let fullName: String?
    internal let signature: String?
    internal let visibility: String
    internal let modifiers: [String]?
    internal let attributes: [String]?
    internal let documentation: Documentation?
    internal let members: [DeclarationOverview]?
    
    internal init(
        path: String,
        type: String,
        name: String,
        fullName: String? = nil,
        signature: String? = nil,
        visibility: String,
        modifiers: [String]? = nil,
        attributes: [String]? = nil,
        documentation: Documentation? = nil,
        members: [DeclarationOverview]? = nil
    ) {
        self.path = path
        self.type = type
        self.name = name
        self.fullName = fullName
        self.signature = signature
        self.visibility = visibility
        self.modifiers = modifiers
        self.attributes = attributes
        self.documentation = documentation
        self.members = members
    }
} 