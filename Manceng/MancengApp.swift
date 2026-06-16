//
//  MancengApp.swift
//  Manceng
//
//  Created by Made Vidyatma Adhi Krisna on 10/06/26.
//

import SwiftUI
import SwiftData

@main
struct MancengApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: CatchModel.self)
    }
}
