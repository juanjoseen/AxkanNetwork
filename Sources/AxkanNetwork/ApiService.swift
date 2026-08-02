//
//  ApiService.swift
//  
//
//  Created by Juan Jose Elias Navarro on 01/08/26.
//

import Foundation

// MARK: - Api Service

/// Servicio principal para realizar llamadas HTTP basadas en un `Endpoint`.
///
/// Uso básico:
/// ```swift
/// Api.setBaseUrl("https://api.ejemplo.com")
/// let api = Api()
/// let usuario: Usuario? = try await api.fetch(endpoint: UsersEndpoint.detail(id: 1), body: nil, responseType: Usuario.self)
/// ```
///
/// Interceptores:
/// - Configure interceptores estáticos para toda la app:
/// ```swift
/// Api.setRequestInterceptors([AuthHeaderInterceptor()])
/// Api.setResponseInterceptors([LoggingResponseInterceptor()])
/// Api.setErrorInterceptors([RetryOn401Interceptor()])
/// ```
///
/// Cree sus propios interceptores:
/// ```swift
/// struct AuthHeaderInterceptor: RequestInterceptor {
///     func intercept(_ request: URLRequest, for endpoint: Endpoint) async throws -> URLRequest {
///         var req = request
///         req.addValue("Bearer TOKEN", forHTTPHeaderField: "Authorization")
///         return req
///     }
/// }
///
/// struct LoggingResponseInterceptor: ResponseInterceptor {
///     func intercept(_ data: Data, _ response: URLResponse, for endpoint: Endpoint) async throws -> (Data, URLResponse) {
///         debugPrint("status: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
///         return (data, response)
///     }
/// }
///
/// struct RetryOn401Interceptor: ErrorInterceptor {
///     func intercept(_ error: Error, request: URLRequest?, response: URLResponse?, for endpoint: Endpoint) async throws {
///         if let http = response as? HTTPURLResponse, http.statusCode == 401 {
///             // Realizar refresh token y NO lanzar error para recuperar
///             return
///         }
///         throw error
///     }
/// }
/// ```
public protocol ApiService {
    /// Ejecuta una solicitud HTTP descrita por `endpoint` y decodifica la respuesta.
    /// - Parameters:
    ///   - endpoint: Objeto que define la ruta, método, headers, cache y timeout.
    ///   - body: Parámetros del cuerpo a enviar. Se codifican con `endpoint.encoder`.
    ///   - responseType: Tipo esperado de la respuesta (conforma a `Codable`).
    /// - Returns: Instancia decodificada del tipo indicado o `nil` si un interceptor de error recupera la ejecución.
    /// - Throws: `ApiError` o errores lanzados por interceptores.
    func fetch<T: Codable & Sendable>(endpoint: Endpoint, body: BodyParameters?, responseType: T.Type) async throws -> T?
}

/// Implementación por defecto de `ApiService` con soporte de interceptores.
@MainActor
public final class Api: ApiService {
    private static var baseUrl: String = ""

    // Interceptors
    private static var requestInterceptors: [RequestInterceptor] = []
    private static var responseInterceptors: [ResponseInterceptor] = []
    private static var errorInterceptors: [ErrorInterceptor] = []

    /// Configura la URL base para construir las rutas de los endpoints.
    /// - Parameter url: Cadena con la URL base (por ejemplo, "https://api.ejemplo.com").
    public static func setBaseUrl(_ url: String) {
        Self.baseUrl = url
    }

    /// Define la lista de interceptores de solicitud que se aplicarán en orden.
    public static func setRequestInterceptors(_ interceptors: [RequestInterceptor]) {
        Self.requestInterceptors = interceptors
    }
    
    /// Agrega un interceptor de solicitud al final de la lista.
    public static func addRequestInterceptor(_ interceptor: RequestInterceptor) {
        Self.requestInterceptors.append(interceptor)
    }

    /// Define la lista de interceptores de respuesta que se aplicarán en orden.
    public static func setResponseInterceptors(_ interceptors: [ResponseInterceptor]) {
        Self.responseInterceptors = interceptors
    }
    
    /// Agrega un interceptor de respuesta al final de la lista.
    public static func addResponseInterceptor(_ interceptor: ResponseInterceptor) {
        Self.responseInterceptors.append(interceptor)
    }

    /// Define la lista de interceptores de error que se aplicarán en orden.
    public static func setErrorInterceptors(_ interceptors: [ErrorInterceptor]) {
        Self.errorInterceptors = interceptors
    }
    
    /// Agrega un interceptor de error al final de la lista.
    public static func addErrorInterceptor(_ interceptor: ErrorInterceptor) {
        Self.errorInterceptors.append(interceptor)
    }

    /// Ejecuta la llamada de red aplicando interceptores de request/response/error.
    /// - Note: Si un `ErrorInterceptor` maneja el error sin lanzar, el método devuelve `nil`.
    public func fetch<T: Codable & Sendable>(endpoint: any Endpoint, body: (any BodyParameters)?, responseType: T.Type) async throws -> T? {
        guard let url: URL = endpoint.url(base: Self.baseUrl) else {
            throw ApiError.badURL
        }

        var request = URLRequest(url: url, cachePolicy: endpoint.cachePolicy, timeoutInterval: endpoint.timeout)
        request.httpMethod = endpoint.method.rawValue

        if let body = body {
            do {
                try endpoint.encoder.encode(body, into: &request)
            } catch {
                throw ApiError.encodingError
            }
        }

        // Apply request interceptors in order
        do {
            for interceptor in Self.requestInterceptors {
                request = try await interceptor.intercept(request, for: endpoint)
            }
        } catch {
            // Give error interceptors a chance to handle/transform
            try await handleError(error, request: request, response: nil, endpoint: endpoint)
        }

        debugPrint("-> Request: \(request)")

        do {
            let (rawData, rawResponse) = try await URLSession.shared.data(for: request)
            debugPrint("-> Response: \(rawResponse)")
            debugPrint("-> Data: \(rawData.toString() ?? "No DATA")")

            // Apply response interceptors in order
            var data = rawData
            var response = rawResponse
            for interceptor in Self.responseInterceptors {
                (data, response) = try await interceptor.intercept(data, response, for: endpoint)
            }

            let statusCode: Int = (response as? HTTPURLResponse)?.statusCode ?? 0
            if statusCode >= 200 && statusCode < 300 {
                let decoder = JSONDecoder()
                return try decoder.decode(responseType, from: data)
            } else {
                let error = ApiError.serverError(error: ErrorType(code: statusCode, message: data.toString() ?? ""))
                // Let error interceptors process the error (may throw or return)
                try await handleError(error, request: request, response: response, endpoint: endpoint)
                return nil
            }
        } catch {
            // Network or decoding error
            try await handleError(error, request: request, response: nil, endpoint: endpoint)
            return nil
        }
    }

    /// Recorre los `ErrorInterceptor` permitiendo recuperación o transformación del error.
    /// Si alguno no lanza, se considera que el error fue manejado.
    private func handleError(_ error: Error, request: URLRequest?, response: URLResponse?, endpoint: Endpoint) async throws {
        var lastError: Error = error
        for interceptor in Self.errorInterceptors {
            do {
                try await interceptor.intercept(lastError, request: request, response: response, for: endpoint)
                // If interceptor completes without throwing, treat as recovered
                return
            } catch {
                lastError = error
            }
        }
        throw lastError
    }
}
