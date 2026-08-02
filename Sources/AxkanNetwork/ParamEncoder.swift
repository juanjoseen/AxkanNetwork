//
//  ParamEncoder.swift
//  
//
//  Created by Juan Jose Elias Navarro on 01/08/26.
//

import Foundation

/// Define cómo serializar un cuerpo (`BodyParameters`) dentro de una `URLRequest`.
///
/// Un `ParamEncoder` decide el formato (JSON, form-url-encoded, multipart, etc.)
/// y añade los headers correspondientes.
///
/// Ejemplo de uso (ya integrado en `Api`):
/// ```swift
/// let encoder: ParamEncoder = JSONParamEncoder()
/// try encoder.encode(body, into: &request)
/// ```
public protocol ParamEncoder {
    /// Codifica el cuerpo y lo inserta en la `URLRequest` (headers y httpBody).
    /// - Parameters:
    ///   - body: Parámetros del cuerpo a serializar.
    ///   - request: Referencia a la solicitud donde se aplicarán cambios.
    func encode(_ body: BodyParameters, into request: inout URLRequest) throws
}

/// Codificador que serializa el cuerpo como JSON usando `Codable`.
/// Agrega el header `Content-Type: application/json` y coloca el JSON en `httpBody`.
public final class JSONParamEncoder: ParamEncoder {
    /// Serializa `BodyParameters` a JSON y lo asigna a `httpBody`.
    public func encode(_ body: BodyParameters, into request: inout URLRequest) throws {
        let data: Data = try body.toJSONData()
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = data
    }
}
