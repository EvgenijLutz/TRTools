// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import WADKit
import TRTools


@main
struct WADEditorCLI {
    static func main() async throws {
        let arguments = CommandLine.arguments
        print("Arguments: " + String(describing: arguments))
        guard arguments.count > 1 else {
            print("No file path provided.")
            return
        }
        
        let currentPath = URL(filePath: arguments[0])
        let url = URL(filePath: arguments[1])
        
        let wad = try await WAD.fromFileURL(url: url)
        let bundles = try await wad.exportGLTFBundles()
        for bundle in bundles {
            let name = String(describing: bundle.type) + ".glb"
            let path = currentPath.deletingLastPathComponent().appending(component: name)
            print("Export " + name)
            try bundle.data.write(to: path)
        }
    }
}
