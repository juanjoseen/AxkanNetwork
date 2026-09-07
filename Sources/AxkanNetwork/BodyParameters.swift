//
//  BodyParameters.swift
//  AxkanNetwork
//
//  Created by Juan Jose Elias Navarro on 07/09/26.
//

import UIKit
import SwiftUI

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

final public class ImageBodyParameter: BodyParameters, Codable {
    private let uiImage: UIImage

    // MARK: - Initializers
    public init(uiImage: UIImage) {
        self.uiImage = uiImage
    }

    /// This initializer must be called on the main actor because SwiftUI `Image` is main-actor isolated.
    @MainActor public init(image: Image) {
        if let converted = image.asUIImage() {
            self.uiImage = converted
        } else {
            self.uiImage = UIImage()
        }
    }

    /// Async initializer that safely hops to the main actor to convert a SwiftUI `Image` to `UIImage`.
    /// Use this from non-main-actor contexts.
    public init(image: Image) async {
        // Hop to main actor to access SwiftUI.Image APIs safely
        let uiImage: UIImage? = await MainActor.run { image.asUIImage() }
        self.uiImage = uiImage ?? UIImage()
    }

    // Convenience accessor back to SwiftUI Image
    public var image: Image { Image(uiImage: uiImage) }

    // MARK: - Codable
    public enum CodingKeys: String, CodingKey { case image }

    public nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let data = try container.decode(Data.self, forKey: .image)
        guard let uiImage = UIImage(data: data) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: ""))
        }
        self.uiImage = uiImage
    }

    public nonisolated func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        guard let data = uiImage.pngData() else {
            throw EncodingError.invalidValue(self, EncodingError.Context(codingPath: [], debugDescription: ""))
        }
        try container.encode(data, forKey: .image)
    }

    // MARK: - BodyParameters
    public nonisolated func toData() -> Data? { uiImage.pngData() }
}
