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
    @Environment(\.refresh) private var refresh
    @Query private var characters: [CharacterModel]
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var errorService: ErrorHandlingService
    @ObservedObject private var dataSyncManager = DataSyncManager.shared
    @ObservedObject private var networkMonitor = NetworkMonitorService.shared
    
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
    @State private var showSyncConflictAlert = false
    
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
                
                SettingsView()
                    .tabItem {
                        Label("설정", systemImage: "gear")
                    }
                    .tag(4)
            }
            .onChange(of: selectedTab) { oldValue, newValue in
                // 탭이 변경될 때 동기화 수행
                if authManager.isLoggedIn && DataSyncManager.shared.hasPendingChanges && networkMonitor.isConnected {
                    Task {
                        await DataSyncManager.shared.safeBackgroundSync()
                    }
                }
            }
            .onAppear {
                let appearance = UITabBarAppearance()
                appearance.configureWithDefaultBackground()
                UITabBar.appearance().standardAppearance = appearance
                
                if #available(iOS 15.0, *) {
                    UITabBar.appearance().scrollEdgeAppearance = appearance
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
            
            // 데이터 동기화 충돌 알림
            if dataSyncManager.hasConflicts && !dataSyncManager.conflictsResolved && authManager.isLoggedIn {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        // 외부 탭 무시
                    }
                
                SyncConflictAlertView(
                    isPresented: $showSyncConflictAlert,
                    onLocalOverCloud: {
                        dataSyncManager.syncStrategy = .localOverCloud
                        performSyncAfterConflict()
                    },
                    onCloudOverLocal: {
                        dataSyncManager.syncStrategy = .cloudOverLocal
                        performSyncAfterConflict()
                    },
                    onMerge: {
                        dataSyncManager.syncStrategy = .merge
                        performSyncAfterConflict()
                    },
                    onDismiss: {
                        showSyncConflictAlert = false
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
        .onChange(of: dataSyncManager.hasConflicts) { _, hasConflicts in
            if hasConflicts && !dataSyncManager.conflictsResolved && authManager.isLoggedIn {
                // 충돌 발생 시 알림 표시
                showSyncConflictAlert = true
            }
        }
    }
    
    // 앱 초기 설정
    private func performInitialSetup() {
        // 레이드 데이터 마이그레이션
        RaidDataMigrationService.shared.checkAndPerformMigrations(modelContext: modelContext)
        
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
        // 네트워크 연결 확인
        guard networkMonitor.isConnected else {
            return
        }
        
        // 최근 체크 시간 확인
        let lastCheck = Date(timeIntervalSince1970: lastUpdateCheckDate)
        let hoursSinceLastCheck = Date().timeIntervalSince(lastCheck) / 3600
        
        // 마지막 체크로부터 24시간 이상 지났는지 확인
        if hoursSinceLastCheck < 24 {
            return
        }
        
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
                await performSyncIfNeeded()
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
    
    // 충돌 해결 후 동기화 수행
    private func performSyncAfterConflict() {
        showSyncConflictAlert = false
        
        Task {
            await dataSyncManager.performManualSync()
        }
    }
}

// 동기화 충돌 알림 뷰
struct SyncConflictAlertView: View {
    @Binding var isPresented: Bool
    var onLocalOverCloud: () -> Void
    var onCloudOverLocal: () -> Void
    var onMerge: () -> Void
    var onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // 알림 제목
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.orange)
                
                Text("데이터 충돌 감지")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("로컬 데이터와 클라우드 데이터가 모두 있습니다.\n어떻게 처리하시겠습니까?")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
            
            // 선택 버튼
            VStack(spacing: 12) {
                Button(action: onMerge) {
                    HStack {
                        Image(systemName: "arrow.triangle.merge")
                        Text("데이터 병합 (권장)")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                
                Button(action: onLocalOverCloud) {
                    HStack {
                        Image(systemName: "arrow.up.to.line")
                        Text("로컬 데이터 우선")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .foregroundColor(.primary)
                    .cornerRadius(10)
                }
                
                Button(action: onCloudOverLocal) {
                    HStack {
                        Image(systemName: "arrow.down.to.line")
                        Text("클라우드 데이터 우선")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .foregroundColor(.primary)
                    .cornerRadius(10)
                }
                
                Button(action: onDismiss) {
                    Text("나중에 결정")
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            }
            .padding(.horizontal)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 20)
        .padding(.horizontal, 32)
    }
}
