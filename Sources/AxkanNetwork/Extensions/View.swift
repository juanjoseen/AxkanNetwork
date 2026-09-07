//
//  View.swift
//  AxkanNetwork
//
//  Created by Juan Jose Elias Navarro on 07/09/26.
//

import SwiftUI

public extension View {
    func asUIImage(scale: CGFloat = 1.0) -> UIImage? {
        let renderer = ImageRenderer(content: self)
        renderer.scale = scale
        return renderer.uiImage
    }
}
