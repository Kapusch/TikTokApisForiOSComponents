// swift-tools-version: 6.0
import PackageDescription

let package = Package(
	name: "KapuschTikTokBusinessInterop",
	platforms: [.iOS(.v15)],
	products: [
		.library(
			name: "KapuschTikTokBusinessInterop",
			type: .static,
			targets: ["KapuschTikTokBusinessInterop"]
		),
	],
	dependencies: [
		.package(path: "../upstream"),
	],
	targets: [
		.target(
			name: "KapuschTikTokBusinessInterop",
			dependencies: [
				.product(name: "TikTokBusinessSDK", package: "upstream"),
			]
		),
	]
)
