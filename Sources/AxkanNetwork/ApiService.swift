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
/// Retry de requests:
/// - Cuando un `ErrorInterceptor` maneja un error sin lanzarlo (por ejemplo, después de refrescar un token),
///   puedes reintentar el último request manualmente:
/// ```swift
/// let resultado: Usuario? = try await api.retryLastRequest()
/// ```
///
/// - O usar el método de conveniencia que reintenta automáticamente:
/// ```swift
/// let usuario: Usuario? = try await api.fetchWithAutoRetry(
///     endpoint: UsersEndpoint.detail(id: 1),
///     body: nil,
///     responseType: Usuario.self,
///     maxRetries: 2
/// )
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
    
    public static let shared: Api = .init()
    public static var verboose: Bool = false
    
    // Retry tracking
    private struct RetryContext {
        let endpoint: any Endpoint
        let body: (any BodyParameters)?
        let responseType: Any.Type
    }
    private var lastRetryContext: RetryContext?

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
        // Save context for potential retry
        lastRetryContext = RetryContext(endpoint: endpoint, body: body, responseType: responseType)
        
        return try await performFetch(endpoint: endpoint, body: body, responseType: responseType)
    }
    
    /// Reintenta el último request ejecutado.
    /// - Returns: La respuesta decodificada o `nil` si no hay contexto previo o un interceptor maneja el error.
    /// - Throws: `ApiError` si no hay request previo para reintentar o errores de la ejecución.
    public func retryLastRequest<T: Codable & Sendable>() async throws -> T? {
        guard let context = lastRetryContext else {
            throw ApiError.noRetryContextAvailable
        }
        
        guard let responseType = context.responseType as? T.Type else {
            throw ApiError.typeMismatch
        }
        
        return try await performFetch(endpoint: context.endpoint, body: context.body, responseType: responseType)
    }
    
    /// Ejecuta la llamada de red real aplicando interceptores de request/response/error.
    private func performFetch<T: Codable & Sendable>(endpoint: any Endpoint, body: (any BodyParameters)?, responseType: T.Type) async throws -> T? {
        guard let url: URL = endpoint.url(base: Self.baseUrl) else {
            throw ApiError.badURL
        }

        var request = URLRequest(url: url, cachePolicy: endpoint.cachePolicy, timeoutInterval: endpoint.timeout)
        request.httpMethod = endpoint.method.rawValue

        if let body = body {
            do {
                try endpoint.encoder.encode(body, into: &request)
            } catch {
                if Self.verboose {
                    print("-> Error decoding: \(error.localizedDescription)")
                }
                throw ApiError.encodingError
            }
        }
        
        // Apply endpoint headers
        endpoint.headers?.forEach { request.addValue($1, forHTTPHeaderField: $0) }
        
        // Apply request interceptors in order
        do {
            var allInterceptors: [RequestInterceptor] = Self.requestInterceptors
            allInterceptors.append(contentsOf: endpoint.requestInterceptors ?? [])
            
            for interceptor in allInterceptors {
                request = try await interceptor.intercept(request, for: endpoint)
            }
        } catch {
            // Give error interceptors a chance to handle/transform
            if Self.verboose {
                print("-> InterceptorError: \(error.localizedDescription)")
            }
            try await handleError(error, request: request, response: nil, endpoint: endpoint)
        }

        if Self.verboose {
            print("-> Request: \(request)")
            print("-> Headers:")
            for (key, value) in request.allHTTPHeaderFields ?? [:] {
                print("----> \(key): \(value)")
            }
            print("End Headers <-")
        }

        do {
            let (rawData, rawResponse) = try await URLSession.shared.data(for: request)
            if Self.verboose {
                print("-> Response: \(rawResponse)")
                print("-> Data: \(rawData.toString() ?? "No DATA")")
            }

            // Apply response interceptors in order
            var data = rawData
            var response = rawResponse
            var allInterceptors: [ResponseInterceptor] = Self.responseInterceptors
            allInterceptors.append(contentsOf: endpoint.responseInterceptors ?? [])
            for interceptor in allInterceptors {
                (data, response) = try await interceptor.intercept(data, response, for: endpoint)
            }

            let statusCode: Int = (response as? HTTPURLResponse)?.statusCode ?? 0
            if statusCode >= 200 && statusCode < 300 {
                let decoder = JSONDecoder()
                return try decoder.decode(responseType, from: data)
            } else {
                if Self.verboose {
                    print("-> StatusCode: \(statusCode)")
                }
                let error = ApiError.serverError(error: ErrorType(code: statusCode, message: data.toString() ?? ""))
                // Let error interceptors process the error (may throw or return)
                try await handleError(error, request: request, response: response, endpoint: endpoint)
                return nil
            }
        } catch {
            // Network or decoding error
            if Self.verboose {
                print("Error: \(error.localizedDescription)")
            }
            try await handleError(error, request: request, response: nil, endpoint: endpoint)
            return nil
        }
    }

    /// Recorre los `ErrorInterceptor` permitiendo recuperación o transformación del error.
    /// Si alguno no lanza, se considera que el error fue manejado.
    private func handleError(_ error: Error, request: URLRequest?, response: URLResponse?, endpoint: Endpoint) async throws {
        var lastError: Error = error
        if Self.verboose {
            print("handleError: \(error)")
        }
        var allInteceptors: [ErrorInterceptor] = Self.errorInterceptors
        allInteceptors.append(contentsOf: endpoint.errorIterceptors ?? [])
        for interceptor in allInteceptors {
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
    
    /// Ejecuta un request con retry automático si un ErrorInterceptor maneja el error.
    /// Este método intenta el request original, y si devuelve nil (indicando que un
    /// interceptor manejó el error), automáticamente reintenta el número especificado de veces.
    ///
    /// - Parameters:
    ///   - endpoint: El endpoint a llamar
    ///   - body: Parámetros del cuerpo (opcional)
    ///   - responseType: El tipo esperado de respuesta
    ///   - maxRetries: Número máximo de reintentos (por defecto 1)
    /// - Returns: La respuesta decodificada o nil si todos los intentos fallaron
    public func fetchWithAutoRetry<T: Codable & Sendable>(
        endpoint: any Endpoint,
        body: (any BodyParameters)? = nil,
        responseType: T.Type,
        maxRetries: Int = 1
    ) async throws -> T? {
        // Primer intento
        if let result = try await fetch(endpoint: endpoint, body: body, responseType: responseType) {
            return result
        }
        
        // Si el resultado fue nil, significa que un interceptor manejó el error
        // Reintentar el número de veces especificado
        for attempt in 1...maxRetries {
            if Self.verboose {
                print("-> Retry attempt \(attempt) of \(maxRetries)")
            }
            
            if let result: T = try await retryLastRequest() {
                return result
            }
        }
        return nil
    }
}
