// swift-tools-version: 5.5

import PackageDescription

let package = Package(
	name: "DSFVersion",
	products: [
		.library(
			name: "DSFVersion",
			targets: ["DSFVersion"]),
	],
	dependencies: [],
	targets: [
		.target(
			name: "DSFVersion",
			dependencies: []),
		.testTarget(
			name: "DSFVersionTests",
			dependencies: ["DSFVersion"]),
	]
)
