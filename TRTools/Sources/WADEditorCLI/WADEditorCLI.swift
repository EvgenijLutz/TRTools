// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation


@main
struct WADEditorCLI {
    static func main() async {
        let arguments = CommandLine.arguments
        
        print("Number of arguments: \(arguments.count) - \(arguments)")
    }
}
