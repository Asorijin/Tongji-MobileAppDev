// swift-tools-version: 6.0
// 仅用于本地"纯 Swift 领域层/导出层/数据层"校验：Windows / macOS 均可 `swift test`。
// Xcode 构建使用 project.yml 生成的工程，本包不参与 CI 的 xcodebuild。
import PackageDescription

let package = Package(
    name: "ParityCheck",
    products: [
        .library(name: "CamCardDomain", targets: ["CamCardDomain"]),
        .library(name: "CamCardExport", targets: ["CamCardExport"]),
        .library(name: "CamCardData", targets: ["CamCardData"]),
    ],
    targets: [
        .target(
            name: "CamCardDomain",
            path: "CamCardClone/Domain",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .target(
            name: "CamCardExport",
            dependencies: ["CamCardDomain"],
            path: "CamCardClone/Services/Export",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .target(
            name: "CamCardData",
            dependencies: ["CamCardDomain"],
            path: "CamCardClone/Data",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "CamCardDomainTests",
            dependencies: ["CamCardDomain", "CamCardExport"],
            path: "CamCardCloneTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "CamCardDataTests",
            dependencies: ["CamCardData", "CamCardDomain"],
            path: "CamCardDataTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
