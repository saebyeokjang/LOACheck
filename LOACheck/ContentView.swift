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
    
    @State private var resetTimer: Timer?
    
    var body: some View {
        TabView(selection: $selectedTab) {
            CharacterPagingView(goToSettingsAction: {
                // 설정 탭으로 이동하는 클로저
                selectedTab = 3
            })
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
            
            setupTaskResetTimer()
        }
        .onDisappear {
            resetTimer?.invalidate()
            resetTimer = nil
        }
    }
    
    // 초기 데이터 로드
    private func loadInitialData() {
        // 처음 앱 실행 시 필요한 초기 데이터 로드
        // 예: 사용자가 등록한 API 키로 캐릭터 정보 불러오기
        if let apiKey = UserDefaults.standard.string(forKey: "apiKey"), !apiKey.isEmpty {
            Task {
                _ = await LostArkAPIService.shared.fetchCharacters(apiKey: apiKey, modelContext: modelContext)
            }
        }
    }
    
    // 리셋 타이머 설정
    private func setupTaskResetTimer() {
        // 이미 타이머가 있다면 취소
        resetTimer?.invalidate()
        
        // 주기적으로 리셋 체크 (30분마다)
        resetTimer = Timer.scheduledTimer(withTimeInterval: 30 * 60, repeats: true) { _ in
            Logger.debug("Running scheduled task reset check")
            TaskResetManager.shared.checkAndResetTasks(modelContext: modelContext)
        }
        
        // 앱 시작 시 즉시 한번 실행
        TaskResetManager.shared.checkAndResetTasks(modelContext: modelContext)
    }
}
