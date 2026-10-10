// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "Probe",
    targets: [.executableTarget(name: "Probe", resources: [.copy("Res")])],
    swiftLanguageModes: [.v5])
