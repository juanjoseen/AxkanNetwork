# AxkanNetwork

Pequeño paquete Swift para manejar networking en iOS.

## Requisitos
- iOS 18 o superior
- Swift 6 (swift-tools-version 6.3)

## Instalación (Swift Package Manager)
Puedes agregar AxkanNetwork a tu proyecto de dos formas:

- Xcode: File > Add Packages… y pega la URL del repositorio. Selecciona la versión deseada y agrega el producto `AxkanNetwork` al/los target(s) correspondientes.
- `Package.swift` manualmente:

```swift
// Dentro de dependencies
.dependencies: [
    .package(url: "https://github.com/tu-usuario/AxkanNetwork.git", from: "1.0.0")
],

// Dentro de targets del app/paquete que lo usa
.targets: [
    .target(
        name: "TuApp",
        dependencies: [
            .product(name: "AxkanNetwork", package: "AxkanNetwork")
        ]
    )
]
