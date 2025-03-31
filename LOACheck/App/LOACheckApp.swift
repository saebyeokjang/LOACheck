//
//  LOACheckApp.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 3/20/25.
//

import SwiftUI
import SwiftData

@main
struct LOACheckApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            CharacterModel.self,
            DailyTask.self,
            RaidGate.self
        ])
    }
}
