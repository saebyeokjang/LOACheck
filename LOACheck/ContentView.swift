//
//  ContentView.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 3/20/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var isInitialLoad = true
    @Environment(\.modelContext) private var modelContext
    @Query private var characters: [CharacterModel]
    
    var body: some View {
        TabView(selection: $selectedTab) {
            CharacterPagingView()
                .tabItem {
                    Label("캐릭터", systemImage: "person.fill")
                }
                .tag(0)
            
            CharacterListView()
                .tabItem {
                    Label("관리", systemImage: "list.bullet")
                }
                .tag(1)
            
            GoldSummaryView()
                .tabItem {
                    Label("골드", systemImage: "dollarsign.circle")
                }
                .tag(2)
            
            SettingsView()
                .tabItem {
                    Label("설정", systemImage: "gear")
                }
                .tag(3)
        }
        .onAppear {
            if isInitialLoad && characters.isEmpty {
                loadInitialData()
                isInitialLoad = false
            }
            
            // 백그라운드에서 일일/주간 리셋 체크
            TaskResetManager.shared.checkAndResetTasks(modelContext: modelContext)
        }
    }
    
    private func loadInitialData() {
        // 처음 앱 실행 시 필요한 초기 데이터 로드
        // 예: 사용자가 등록한 API 키로 캐릭터 정보 불러오기
        if let apiKey = UserDefaults.standard.string(forKey: "apiKey"), !apiKey.isEmpty {
            Task {
                await LostArkAPIService.shared.fetchCharacters(apiKey: apiKey, modelContext: modelContext)
            }
        }
    }
}
