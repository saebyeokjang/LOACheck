//
//  ContentView.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 3/20/25.
//

import SwiftUI
import SwiftData
import FirebaseAnalytics

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var isInitialLoad = true
    @Environment(\.modelContext) private var modelContext
    @Environment(\.refresh) private var refresh
    @Query private var characters: [CharacterModel]
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var errorService: ErrorHandlingService
    @ObservedObject private var dataSyncManager = DataSyncManager.shared
    @ObservedObject private var networkMonitor = NetworkMonitorService.shared
    @ObservedObject private var friendsService = FriendsService.shared
    
    @State private var resetTimer: Timer?
    
    // 앱 업데이트 관련 상태
    @State private var showUpdateAlert = false
    @State private var latestVersion = ""
    @State private var releaseNotes: String? = nil
    @AppStorage("lastUpdateCheckDate") private var lastUpdateCheckDate = Date.distantPast.timeIntervalSince1970
    @AppStorage("skipVersion") private var skipVersion = ""
    
    // 로그인 화면 표시 여부
    @State private var showSignIn = false
    
    // 동기화 충돌 알림 표시 여부
    //@State private var showSyncConflictAlert = false
    
    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                CharacterPagingView(goToSettingsAction: {
                    // 설정 탭으로 이동하는 클로저
                    selectedTab = 4
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
                
                MarketView()
                    .tabItem {
                        Label("시세", systemImage: "magnifyingglass")
                    }
                    .tag(2)
                
                FriendsListView()
                    .tabItem {
                        Label("친구", systemImage: "person.2.fill")
                    }
                    .tag(3)
                    .badge(friendRequestBadge)
                
                SettingsView()
                    .tabItem {
                        Label("설정", systemImage: "gear")
                    }
                    .tag(4)
            }
            .onChange(of: selectedTab) { oldValue, newValue in
                Logger.debug("탭 변경: \(oldValue) -> \(newValue)")
                
                // 즉시 실행되는 동기화 코드 추가
                if authManager.isLoggedIn && DataSyncManager.shared.hasPendingChanges && networkMonitor.isConnected {
                    Task {
                        let result = await DataSyncManager.shared.uploadToServer()
                        Logger.debug("탭 변경으로 인한 동기화 결과: \(result ? "성공" : "실패")")
                    }
                }
                
                // 친구 탭으로 이동할 때 친구 정보 새로고침
                if newValue == 3 && authManager.isLoggedIn {
                    Task {
                        await friendsService.loadFriendRequests()
                    }
                }
                
                // 탭 전환 이벤트 기록
                let tabNames = ["캐릭터", "관리", "시세", "친구", "설정"]
                Analytics.logEvent("tab_switch", parameters: [
                    "from_tab": tabNames[oldValue],
                    "to_tab": tabNames[newValue]
                ])
                
            }
            .onAppear {
                performInitialSetup()
                let appearance = UITabBarAppearance()
                appearance.configureWithDefaultBackground()
                UITabBar.appearance().standardAppearance = appearance
                
                if #available(iOS 15.0, *) {
                    UITabBar.appearance().scrollEdgeAppearance = appearance
                }
                
                // 로그인되어 있으면 친구 요청 로드
                if authManager.isLoggedIn {
                    Task {
                        await friendsService.loadFriendRequests()
                    }
                }
            }
            .onDisappear {
                resetTimer?.invalidate()
                resetTimer = nil
            }
            .overlay(OfflineOverlayView())
            
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
        .sheet(isPresented: $showSignIn) {
            SignInView(isPresented: $showSignIn)
                .onDisappear {
                    // 로그인 완료 후 데이터 마이그레이션 및 동기화
                    if authManager.isLoggedIn {
                        checkSyncAfterLogin()
                    }
                }
        }
        .onChange(of: authManager.isLoggedIn) { _, isLoggedIn in
            if isLoggedIn {
                // 로그인 상태가 되었을 때 동기화 확인
                checkSyncAfterLogin()
                
                // 친구 요청 로드
                Task {
                    await friendsService.loadFriendRequests()
                }
            }
        }
        .onChange(of: networkMonitor.isConnected) { _, isConnected in
            if isConnected && authManager.isLoggedIn && dataSyncManager.hasPendingChanges {
                // 네트워크 연결이 복구되고 동기화 필요 시 동기화 시도
                Task {
                    await performSyncIfNeeded()
                }
            }
        }
        //        .onChange(of: dataSyncManager.hasConflicts) { _, hasConflicts in
        //            if hasConflicts && !dataSyncManager.conflictsResolved && authManager.isLoggedIn {
        //                // 충돌 발생 시 알림 표시
        //                showSyncConflictAlert = true
        //            }
        //        }
    }
    
    // 친구 요청 배지 계산
    private var friendRequestBadge: Int {
        return authManager.isLoggedIn && !friendsService.friendRequests.isEmpty ?
        friendsService.friendRequests.count : 0
    }
    
    // 앱 초기 설정
    private func performInitialSetup() {
        // 레이드 데이터 마이그레이션
        RaidDataMigrationService.shared.checkAndPerformMigrations(modelContext: modelContext)
        
        // additionalGold 동기화
        syncAdditionalGoldForAllCharacters()
        
        // 일일 리셋 체크
        setupTaskResetTimer()
        
        // 앱 업데이트 확인
        checkForAppUpdate()
        
        // 네트워크 상태 확인 후 필요시 데이터 동기화
        if networkMonitor.isConnected && authManager.isLoggedIn {
            Task {
                await performSyncIfNeeded()
            }
        }
        
        // 로컬 데이터가 비었고 로그인 상태면 클라우드에서 동기화
        if characters.isEmpty && authManager.isLoggedIn && networkMonitor.isConnected {
            Task {
                await dataSyncManager.pullFromCloud()
            }
        }
        
        // 로컬 데이터가 비었고 API 키가 있으면 캐릭터 정보 불러오기
        if characters.isEmpty,
           let apiKey = UserDefaults.standard.string(forKey: "apiKey"),
           !apiKey.isEmpty,
           networkMonitor.isConnected {
            Task {
                _ = await LostArkAPIService.shared.fetchCharacters(apiKey: apiKey, modelContext: modelContext)
            }
        }
    }
    
    // 모든 캐릭터의 additionalGold 동기화하는 함수
    private func syncAdditionalGoldForAllCharacters() {
        Task {
            do {
                let descriptor = FetchDescriptor<CharacterModel>()
                if let characters = try? modelContext.fetch(descriptor) {
                    for character in characters {
                        character.synchronizeAdditionalGold()
                    }
                    Logger.info("모든 캐릭터의 additionalGold 동기화 완료: \(characters.count)개 캐릭터")
                }
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
        
        // 네트워크 연결 확인 (로그 추가)
        if !networkMonitor.isConnected {
            Logger.debug("네트워크 연결 없음, 업데이트 체크 건너뜀")
            return
        }
        
        // 최근 체크 시간 확인 (더 자세한 로그)
        let lastCheck = Date(timeIntervalSince1970: lastUpdateCheckDate)
        let hoursSinceLastCheck = Date().timeIntervalSince(lastCheck) / 3600
        Logger.debug("마지막 업데이트 체크 이후 경과 시간: \(hoursSinceLastCheck)시간")
        
        // 앱 처음 설치 시나 업데이트 후 첫 실행 시에는 무조건 체크
        let lastKnownVersion = UserDefaults.standard.string(forKey: "lastKnownVersion") ?? ""
        let isFirstRunAfterUpdate = lastKnownVersion != currentVersion
        
        // 마지막 체크로부터 24시간 이상 지났는지 또는 앱 업데이트 후 첫 실행인지 확인
        if hoursSinceLastCheck < 24 && !isFirstRunAfterUpdate {
            Logger.debug("24시간 이내에 이미 체크함, 업데이트 체크 건너뜀")
            return
        }
        
        // 현재 버전 저장
        UserDefaults.standard.set(currentVersion, forKey: "lastKnownVersion")
        
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
        if let url = URL(string: "itms-apps://itunes.apple.com/app/id\(AppUpdateService.appID)") {
            UIApplication.shared.open(url)
        }
    }
    
    // 로그인 후 동기화 확인
    private func checkSyncAfterLogin() {
        // 초기 마이그레이션 수행
        DataMigrationService.shared.performInitialMigrationAfterLogin(modelContext: modelContext)
        
        // 네트워크 연결 확인 후 동기화
        if networkMonitor.isConnected {
            Task {
                await dataSyncManager.uploadToServer()
            }
        } else {
            // 오프라인 상태면 변경 사항 표시
            dataSyncManager.markLocalChanges()
        }
    }
    
    // 필요시 동기화 수행
    private func performSyncIfNeeded() async {
        if authManager.isLoggedIn && networkMonitor.isConnected {
            if dataSyncManager.hasPendingChanges || characters.isEmpty {
                await dataSyncManager.performManualSync()
            }
        }
    }
}
