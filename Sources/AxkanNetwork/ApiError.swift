//
//  ApiError.swift
//  
//
//  Created by Juan Jose Elias Navarro on 01/08/26.
//

import Foundation

/// Representa los errores de red y de procesamiento que pueden ocurrir al usar el framework.
///
/// Este enum centraliza las fallas más comunes al construir solicitudes, comunicarse con el servidor
/// y decodificar respuestas. Úsalo para mostrar mensajes de error consistentes y para manejar
/// lógicas de recuperación (por ejemplo, con interceptores de error).
public enum ApiError: Error, Equatable {
    /// No fue posible contactar al servidor (posible falta de conexión a internet o caída del servicio).
    case noServer
    /// La URL construida para la solicitud es inválida.
    case badURL
    /// La respuesta del servidor no contiene datos.
    case noData
    /// Ocurrió un error al decodificar la respuesta a un tipo `Codable`.
    case decodingError
    /// Ocurrió un error al codificar el cuerpo de la solicitud.
    case encodingError
    /// La operación se completó correctamente pero no devolvió resultados.
    case noResults
    /// Error genérico con un mensaje descriptivo proporcionado por la capa superior.
    case text(message: String)
    /// Error devuelto por el servidor con código y mensaje estructurados.
    case serverError(error: ErrorType)
    
    /// Mensaje de error legible para el usuario final.
    var localizedDescription: String {
        switch self {
        case .noServer:
            return "Estamos teniendo problemas para conectarnos a los servidores.\n\nPor favor, revisa tu conexión a internet e inténtalo de nuevo más tarde."
        case .badURL:
            return "¡Ups! Parece que el enlace tiene un error.\n\nPor favor inténtalo de nuevo más tarde.."
        case .noData:
            return "Lo sentimos, no pudimos recibir datos.\n\nPor favor inténtalo de nuevo más tarde."
        case .decodingError:
            return "Lo sentimos, no se pudieron leer los datos recibidos.\n\nPor favor inténtalo de nuevo más tarde."
        case .encodingError:
            return "¡Ups! Parece que los datos enviados son incorrectos.\n\nPor favor inténtalo de nuevo más tarde."
        case .text(let message):
            return message
        case .noResults:
            return "Lo sentimos, no pudimos encontrar ningún resultado.\n\nPrueba con una búsqueda diferente o inténtalo de nuevo más tarde."
        case .serverError(let error):
            return error.message
        }
    }
    
    /// Mensaje corto para mostrar en UI compacta (toasts, banners, etc.).
    var shorMessage: String {
        switch self {
        case .noServer:
            return "No hay conexión"
        case .badURL:
            return "Enlace incorrecto"
        case .noData:
            return "No hay datos"
        case .decodingError:
            return "Error de decodificación"
        default:
            return "Error desconocido"
        }
    }
}

/// Representa un error proveniente del servidor con un código y un mensaje.
/// Útil para mapear errores de dominio específicos.
public struct ErrorType: Codable, Equatable {
    /// Código numérico del error.
    var code: Int
    /// Descripción del error devuelta por el servidor.
    var message: String
    
    /// Error estándar para credenciales inválidas.
    static let INVALID_CREDENTIALS: ErrorType = .init(code: 4501, message: "Credenciales inválidas")
    /// Error genérico/desconocido cuando no se puede determinar la causa exacta.
    static let unknown: ErrorType = .init(code: 0, message: "Error Desconocido")
    
    /// Compara dos errores por su código.
    public static func == (lhs: ErrorType, rhs: ErrorType) -> Bool {
        return lhs.code == rhs.code
    }
}
