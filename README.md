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
```

## Uso

### Configuración inicial
Para configurarlo usando SwiftUI dentro de tu estructura que conforma el protocolo `App`,  

- Importa AxkanNetwork

```swift
import AxkanNetwork
```

- Configura el basePath de tus servicios junto con los interceptors

```swift
@main
struct ExampleApp: App {
    // register your basePath
    init() {
        Api.setBaseUrl("https://example.com")
        Api.setRequestInterceptors( ... )
        Api.setResponseInterceptors( ... )
        Api.setErrorInterceptors( ... )        
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### Configura tu endpoint

```swift
import AxkanNetwork

...

struct LoginEndpoint: Endpoint {
    var method: HTTPMethod { .post }
    var path: String = "/auth/login"
    ...
} 

```

### Envia tu request

```swift

struct LoginBody: BodyParameters {
    let username: String
    let password: String
} 

...

func login(username: String, password: String) -> throws async {
    let body: LoginBody(username: username, password: password)
    let endpoint = LoginEndpoint()
    
    if let token: TokenResponse = try await Api.shared.fetch(endpoint: endpoint, body: body, responseType: TokenResponse.self) {
        // Some validations here
    }
}

```
