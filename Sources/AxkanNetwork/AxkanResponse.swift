//
//  AxkanResponse.swift
//  AxkanNetwork
//
//  Created by Juan Jose Elias Navarro on 07/09/26.
//

import Foundation

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
