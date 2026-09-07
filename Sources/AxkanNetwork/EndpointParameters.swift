//
//  EndpointParameters.swift
//  AxkanNetwork
//
//  Created by Juan Jose Elias Navarro on 07/09/26.
//

import Foundation

/// Define un contrato para convertir parámetros en query items.
public protocol EndpointParameters {
    /// Convierte los parámetros en un arreglo de `URLQueryItem` para componer la URL.
    func toQueryItems() -> [URLQueryItem]
}

public extension EndpointParameters {
    func toQueryItems() -> [URLQueryItem] {
        Mirror(reflecting: self).children.compactMap { child in
            guard let name = child.label else { return nil }
            let valueMirror = Mirror(reflecting: child.value)
            if valueMirror.displayStyle == .optional, valueMirror.children.first == nil {
                return nil
            }
            return URLQueryItem(name: name, value: String(describing: child.value))
        }
    }
}
