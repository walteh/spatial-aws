// swift-tools-version:6.0

import PackageDescription

let package = Package(
	name: "SpatialAWS",
	platforms: [
		.iOS(.v17),
		.macOS(.v14),
		.visionOS(.v1),
	],
	products: [
		.executable(
			name: "SpatialAWS",
			targets: ["SpatialAWS"]
		),
	],
	dependencies: [
		.package(url: "https://github.com/walteh/xdk", from: "0.55.0"),
		.package(url: "https://github.com/apple/swift-testing.git", branch: "main"),
	],
	targets: [
		.executableTarget(
			name: "SpatialAWS",
			dependencies: [
				.product(name: "XDK", package: "xdk"),
				.product(name: "XDKAWSSSO", package: "xdk"),
				.product(name: "XDKKeychain", package: "xdk"),
				.product(name: "XDKLogging", package: "xdk"),
			],
			path: "Sources/SpatialAWS",
			resources: [
				.process("../../Resources"),
			]
		),
		.testTarget(
			name: "SpatialAWSTests",
			dependencies: ["SpatialAWS", .product(name: "Testing", package: "swift-testing")],
			path: "Tests/SpatialAWSTests"
		),
		// .testTarget(
		//     name: "SpatialAWSUITests",
		//     dependencies: ["SpatialAWS"],
		//     path: "Tests/SpatialAWSUITests"
		// ),
	]
)
