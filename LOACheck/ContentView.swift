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
    
    // 업데이트 관련 상태
    @State private var showUpdateAlert = false
    @State private var latestVersion = ""
    @State private var releaseNotes: String? = nil
    @AppStorage("lastUpdateCheckDate") private var lastUpdateCheckDate = Date.distantPast.timeIntervalSince1970
    @AppStorage("skipVersion") private var skipVersion = ""
    
    var body: some View {
        ZStack {
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
                
                // 레이드 데이터 마이그레이션
                RaidDataMigrationService.shared.checkAndPerformMigrations(modelContext: modelContext)
                
                setupTaskResetTimer()
                checkForAppUpdate()
            }
            .onDisappear {
                resetTimer?.invalidate()
                resetTimer = nil
            }
            
            // 업데이트 알림 오버레이
            if showUpdateAlert {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        // 외부 탭 무시
                    }
                
                UpdateAlertView(
                    isPresented: $showUpdateAlert,
                    currentVersion: AppUpdateService.shared.getCurrentAppVersion(),
                    latestVersion: latestVersion,
                    releaseNotes: releaseNotes,
                    onUpdate: {
                        openAppStore()
                    },
                    onLater: {
                        // 나중에 버튼 - 하루 후 다시 체크
                        lastUpdateCheckDate = Date().addingTimeInterval(24 * 60 * 60).timeIntervalSince1970
                    }
                )
                .transition(.scale)
                .zIndex(1)
            }
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
    
    // 앱 업데이트 확인
    private func checkForAppUpdate() {
        // 현재 버전 로깅
        let currentVersion = AppUpdateService.shared.getCurrentAppVersion()
        Logger.debug("현재 앱 버전: \(currentVersion)")
        
        Task {
            // 최신 버전 정보 가져오기
            let result = await AppUpdateService.shared.checkForUpdate()
            
            await MainActor.run {
                // 업데이트 확인 날짜 저장
                lastUpdateCheckDate = Date().timeIntervalSince1970
                
                switch result {
                case .success(let versionInfo):
                    latestVersion = versionInfo.latestVersion
                    releaseNotes = versionInfo.releaseNotes
                    
                    Logger.debug("앱스토어 버전: \(latestVersion), 릴리즈 노트: \(releaseNotes ?? "없음")")
                    
                    // 업데이트 필요성 확인
                    let updateAvailable = AppUpdateService.shared.isUpdateAvailable(
                        currentVersion: currentVersion,
                        latestVersion: latestVersion
                    )
                    
                    // 이미 스킵한 버전인지 확인
                    let isSkippedVersion = skipVersion == latestVersion
                    
                    Logger.debug("업데이트 확인 결과 - 현재: \(currentVersion), 최신: \(latestVersion), 업데이트 필요: \(updateAvailable), 스킵됨: \(isSkippedVersion)")
                    
                    // 업데이트 필요하고 스킵한 버전이 아니면 알림 표시
                    if updateAvailable && !isSkippedVersion {
                        Logger.debug("업데이트 알림 표시")
                        showUpdateAlert = true
                    } else {
                        Logger.debug("업데이트 알림 표시하지 않음")
                    }
                    
                case .failure(let error):
                    Logger.error("업데이트 확인 실패: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // 앱스토어 열기
    private func openAppStore() {
        if let url = URL(string: "itms-apps://itunes.apple.com/app/id6743695129") {
            UIApplication.shared.open(url)
        }
    }
}
