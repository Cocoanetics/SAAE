import Foundation
import SAAE

extension DeclarationOverview {
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "name": name,
            "type": type,
            "path": path,
            "visibility": visibility
        ]
        
        if let fullName = fullName {
            dict["fullName"] = fullName
        }
        
        if let signature = signature {
            dict["signature"] = signature
        }
        
        if let attributes = attributes {
            dict["attributes"] = attributes
        }
        
        if let documentation = documentation {
            var docDict: [String: Any] = [
                "description": documentation.description
            ]
            
            if !documentation.parameters.isEmpty {
                docDict["parameters"] = documentation.parameters
            }
            
            if let returns = documentation.returns {
                docDict["returns"] = returns
            }
            
            if let throwsInfo = documentation.throwsInfo {
                docDict["throws"] = throwsInfo
            }
            
            dict["documentation"] = docDict
        }
        
        if let members = members {
            dict["members"] = members.map { $0.toDictionary() }
        }
        
        return dict
    }
} 