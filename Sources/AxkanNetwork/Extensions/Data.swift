//
//  Data.swift
//  
//
//  Created by Juan Jose Elias Navarro on 01/08/26.
//

import Foundation

extension Data {
    func toString() -> String? {
        String(data: self, encoding: .utf8)
    }
}
