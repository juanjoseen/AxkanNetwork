//
//  Dictionary.swift
//  AxkanNetwork
//
//  Created by Juan Jose Elias Navarro on 07/09/26.
//

import Foundation

public extension Dictionary where Key == String, Value == Any {
    func imageBodyData(boundary: String) -> Data {
        var body: Data = Data()
        let lineBreak = "\r\n"
        
        for (key, value) in self {
            
            guard let fileData = value as? Data else { continue }
            
            body.append("--\(boundary)\(lineBreak)".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"; filename=\"\(key).png\"\(lineBreak)".data(using: .utf8)!)
            body.append("Content-Type: image/png\(lineBreak)\(lineBreak)".data(using: .utf8)!)
            body.append(fileData)
            body.append("\(lineBreak)".data(using: .utf8)!)
        }
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        return body
    }
}
