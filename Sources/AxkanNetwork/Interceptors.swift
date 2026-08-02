//
//  Interceptors.swift
//  
//
//  Created by Juan Jose Elias Navarro on 01/08/26.
//

import Foundation

/// Protocolo para interceptar y/o modificar la solicitud antes de ser enviada.
/// Útil para: añadir cabeceras (Authorization, Content-Type), firmar peticiones,
/// registrar logs, o cancelar una solicitud si no cumple ciertas reglas.
public protocol RequestInterceptor {
    /// Intercepta la `URLRequest` antes de ejecutar la llamada.
    /// - Parameters:
    ///   - request: La solicitud original construida a partir del `Endpoint`.
    ///   - endpoint: El endpoint que describe la operación a realizar.
    /// - Returns: Una `URLRequest` (posiblemente modificada) que se usará en la llamada.
    /// - Throws: Lanza un error para abortar la ejecución de la solicitud.
    func intercept(_ request: URLRequest, for endpoint: Endpoint) async throws -> URLRequest
}

/// Protocolo para interceptar y/o modificar la respuesta cruda (Data/URLResponse)
/// antes de ser decodificada. Útil para: normalizar respuestas, des-envolver
/// payloads, registrar métricas o validar status codes personalizados.
public protocol ResponseInterceptor {
    /// Intercepta la respuesta cruda posterior a la llamada de red.
    /// - Parameters:
    ///   - data: Datos crudos devueltos por la red.
    ///   - response: Respuesta de la red (`URLResponse`/`HTTPURLResponse`).
    ///   - endpoint: El endpoint solicitado.
    /// - Returns: Una tupla con `Data` y `URLResponse` (posiblemente modificados).
    /// - Throws: Lanza para indicar que la respuesta debe tratarse como error.
    func intercept(_ data: Data, _ response: URLResponse, for endpoint: Endpoint) async throws -> (Data, URLResponse)
}

/// Protocolo para interceptar errores, permitiendo transformarlos o recuperarse.
/// Útil para: reintentos, refresco de tokens, mapeo de errores de servidor a
/// errores de dominio, o registro centralizado de fallos.
public protocol ErrorInterceptor {
    /// Intercepta un error producido durante la preparación, ejecución o procesamiento.
    /// - Parameters:
    ///   - error: El error original.
    ///   - request: La solicitud asociada (si aplica).
    ///   - response: La respuesta asociada (si aplica).
    ///   - endpoint: El endpoint que se intentaba ejecutar.
    /// - Throws: Lanza para propagar/reemplazar el error. Si no lanza, se considera recuperado.
    func intercept(_ error: Error, request: URLRequest?, response: URLResponse?, for endpoint: Endpoint) async throws
}

/// Interceptor comodín que agrupa los tres tipos. Conforma a los tres protocolos.
public protocol Interceptor: RequestInterceptor, ResponseInterceptor, ErrorInterceptor {}

// Implementaciones por defecto para que cada hook sea opcional.
public extension RequestInterceptor {
    func intercept(_ request: URLRequest, for endpoint: Endpoint) async throws -> URLRequest { request }
}

public extension ResponseInterceptor {
    func intercept(_ data: Data, _ response: URLResponse, for endpoint: Endpoint) async throws -> (Data, URLResponse) { (data, response) }
}

public extension ErrorInterceptor {
    func intercept(_ error: Error, request: URLRequest?, response: URLResponse?, for endpoint: Endpoint) async throws { throw error }
}
