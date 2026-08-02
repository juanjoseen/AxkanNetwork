//
//  Encodable.swift
//  
//
//  Created by Juan Jose Elias Navarro on 01/08/26.
//

import Foundation

public extension Encodable {
    var dictionary: [String: Any]? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any]
    }
    
    func toJSONData() throws -> Data {
        let data = try JSONEncoder().encode(self)
        return data
    }
    
    func toUnescapedJSONData() throws -> Data {
        let encoder: JSONEncoder = JSONEncoder()
        encoder.outputFormatting = .withoutEscapingSlashes
        return try encoder.encode(self)
    }
}
º
