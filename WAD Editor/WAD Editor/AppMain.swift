//
//  AppMain.swift
//  WAD Editor
//
//  Created by Evgenij Lutz on 29.01.24.
//

import SwiftUI


#if os(macOS)

import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

#endif



@main
struct WADEditorApp: App {
    
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif
    
    var body: some Scene {
        WindowGroup {
            //NavigatorTestView()
            ContentView()
        }
    }
}
