//
//  AxkanViewModel.swift
//  AxkanNetwork
//
//  Created by Juan Jose Elias Navarro on 22/08/26.
//

@MainActor
public protocol AxkanViewModel: AnyObject {
    var isLoading: Bool { get set }
    var error: ApiError? { get set }
    func performRequest<T: Codable & Sendable>(endpoint: some Endpoint, body: (any BodyParameters)?, completion: @escaping (T?) -> Void)
}

public extension AxkanViewModel {
    /// Método genérico para realizar peticiones a la API y manejar errores de forma centralizada.
    /// - Parameters:
    ///   - endpoint: El endpoint a consumir.
    ///   - body: El contenido de Body para el request
    ///   - completion: Closure que se ejecuta con la respuesta decodificada o `nil` en caso de error.
    func performRequest<T: Codable & Sendable>(
        endpoint: some Endpoint,
        body: (any BodyParameters)? = nil,
        completion: @escaping (T?) -> Void
    ) {
        isLoading = true
        error = nil
        
        Task {
            defer { self.isLoading = false }
            
            do {
                if Task.isCancelled { return }
                
                let result = try await Api.shared.fetch(
                    endpoint: endpoint,
                    body: body,
                    responseType: AxkanResponse<T>.self
                )
                
                completion(result?.data)
                
            } catch let apiError as ApiError {
                print("❌ APIError -> \(apiError)")
                await MainActor.run {
                    self.error = apiError
                }
                completion(nil)
            } catch {
                print("❌ Error: \(error.localizedDescription)")
                await MainActor.run {
                    self.error = .text(message: error.localizedDescription)
                }
                completion(nil)
            }
        }
    }
}

