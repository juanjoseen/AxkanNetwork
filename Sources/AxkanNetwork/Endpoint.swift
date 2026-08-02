//
//  Endpoint.swift
//  
//
//  Created by Juan Jose Elias Navarro on 01/08/26.
//

import Foundation

/// Define un contrato para describir un recurso HTTP (endpoint) de forma declarativa.
///
/// Un `Endpoint` encapsula la información necesaria para construir una solicitud:
/// método, ruta, parámetros de consulta, cabeceras, timeout, política de caché y el codificador
/// que se usará para el cuerpo de la petición.
///
/// Ejemplo de implementación:
/// ```swift
/// enum UsersEndpoint: Endpoint {
///     case list
///     case detail(id: Int)
///
///     var method: HTTPMethod { .get }
///     var path: String {
///         switch self {
///         case .list: return "/users"
///         case .detail(let id): return "/users/\(id)"
///         }
///     }
///     var parameters: EndpointParameters? { nil }
/// }
/// ```
public protocol Endpoint: Sendable {
    /// Método HTTP (GET, POST, PUT, DELETE, etc.).
    var method: HTTPMethod { get }
    /// Ruta relativa del recurso (por ejemplo, "/users").
    var path: String { get }
    /// Parámetros de consulta para la URL (opcional).
    var parameters: EndpointParameters? { get }
    /// Cabeceras HTTP adicionales a enviar (opcional).
    var headers: HTTPHeaders? { get }
    /// Tiempo máximo de espera de la solicitud en segundos.
    var timeout: TimeInterval { get }
    /// Política de caché a usar para la solicitud.
    var cachePolicy: URLRequest.CachePolicy { get }
    /// Codificador a utilizar para serializar el cuerpo (por ejemplo, JSON).
    var encoder: ParamEncoder { get }
}

/// Representa un diccionario de cabeceras HTTP.
public typealias HTTPHeaders = [String: String]

public extension Endpoint {
    /// Construye la URL absoluta combinando la base y el `path`, agregando `parameters` como query items.
    /// - Parameter base: URL base del servicio (por ejemplo, "https://api.ejemplo.com").
    /// - Returns: URL resultante o `nil` si no se pudo construir.
    func url(base: String) -> URL? {
        let urlString = base + path
        guard var urlComponents = URLComponents(string: urlString) else { return nil }
        if let parameters = parameters {
            urlComponents.queryItems = parameters.toQueryItems()
        }
        return urlComponents.url
    }
    
    /// Valor por defecto: sin parámetros de consulta.
    var parameters: EndpointParameters? { nil }
    /// Valor por defecto: sin cabeceras adicionales.
    var headers: HTTPHeaders? { nil }
    /// Valor por defecto: 30 segundos de timeout.
    var timeout: TimeInterval { 30.0 }
    /// Valor por defecto: `useProtocolCachePolicy`.
    var cachePolicy: URLRequest.CachePolicy { .useProtocolCachePolicy }
    /// Valor por defecto: `JSONParamEncoder` para serializar cuerpos en JSON.
    var encoder: ParamEncoder { JSONParamEncoder() }
}

/// Define un contrato para convertir parámetros en query items.
public protocol EndpointParameters {
    /// Convierte los parámetros en un arreglo de `URLQueryItem` para componer la URL.
    func toQueryItems() -> [URLQueryItem]
}

public protocol BodyParameters: Codable, Sendable {
    /// Convierte el cuerpo a `Data` listo para enviar. Retorna `nil` si no es posible serializar.
    func toData() -> Data?
}

public extension BodyParameters {
    /// Serializa el cuerpo a JSON usando `Codable`.
    func toData() -> Data? {
        try? self.toJSONData()
    }
}

/// Contenedor de respuesta genérico del backend Axkan.
///
/// - success: indica si la operación fue exitosa.
/// - error: información de error estructurada (si aplica).
/// - data: carga útil con el tipo solicitado.
public struct AxkanResponse<T: Codable & Sendable>: Codable, Sendable {
    /// Indica si la operación fue exitosa.
    public var success: Bool
    /// Error asociado en caso de fallo.
    public var error: ErrorType?
    /// Carga útil devuelta por el servicio.
    public var data: T?
}
