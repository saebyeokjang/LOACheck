//
//  LOACheckApp.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 3/20/25.
//

import SwiftUI
import SwiftData
import FirebaseCore

@main
struct LOACheckApp: App {
    // Firebase 및 인증 관리자 초기화
    @StateObject private var authManager = AuthManager.shared
    
    init() {
        // Firebase 초기화
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
        }
        .modelContainer(for: [
            CharacterModel.self,
            DailyTask.self,
            RaidGate.self
        ], isAutosaveEnabled: true) { result in
            switch result {
            case .success(let container):
                DataSyncManager.shared.setModelContext(container.mainContext)
            case .failure(let error):
                print("ModelContainer 생성 실패: \(error)")
            }
        }
    }
}
