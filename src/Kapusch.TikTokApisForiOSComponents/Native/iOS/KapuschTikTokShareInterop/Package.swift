// swift-tools-version: 6.0
import PackageDescription

let package = Package(
	name: "KapuschTikTokShareInterop",
	platforms: [.iOS(.v15)],
	products: [
		.library(
			name: "KapuschTikTokShareInterop",
			type: .static,
			targets: ["KapuschTikTokShareInterop"]
		),
	],
	dependencies: [
		.package(path: "../upstream"),
	],
	targets: [
		.target(
			name: "KapuschTikTokShareInterop",
			dependencies: [
				.product(name: "TikTokOpenSDKCore", package: "upstream"),
				.product(name: "TikTokOpenShareSDK", package: "upstream"),
			]
		),
	]
)
