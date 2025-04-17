//
//  LOACheckApp.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 3/20/25.
//

import SwiftUI
import SwiftData
import FirebaseCore
import GoogleSignIn
import FirebaseAnalytics

@main
struct LOACheckApp: App {
    // 인증 및 서비스 관리자 초기화
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var errorHandlingService = ErrorHandlingService.shared
    @StateObject private var networkMonitor = NetworkMonitorService.shared
    @StateObject private var friendsService = FriendsService.shared
    
    // 앱 시작 시 초기화 플래그
    @State private var isInitialized = false
    
    init() {
        // Firebase 초기화
        FirebaseApp.configure()
        
        // Analytics 활성화
        Analytics.setAnalyticsCollectionEnabled(true)
        
        // 로그 시스템 초기화
        setupLoggingSystem()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(errorHandlingService)
                .environmentObject(friendsService)
                .environment(\.refresh, RefreshAction {
                    // 앱 전체 새로고침 로직 - 동기 함수로 변경
                    Task { await performGlobalRefresh() }
                })
                .onOpenURL { url in
                    // 구글 로그인 URL 처리
                    GIDSignIn.sharedInstance.handle(url)
                }
                .onAppear {
                    if !isInitialized {
                        setupAppLifecycleHandlers()
                        setupPeriodicSync()
                        
                        // 앱 시작 시 로그인 상태라면 친구 리스너 설정
                        if authManager.isLoggedIn {
                            friendsService.setupListeners()
                            Task {
                                await performLocalPrioritySync()
                            }
                        }
                        
                        isInitialized = true
                        
                        let sessionStartTime = Date()
                        Analytics.logEvent("app_session_start", parameters: [
                            "user_logged_in": authManager.isLoggedIn,
                            "device_model": UIDevice.current.model,
                            "os_version": UIDevice.current.systemVersion,
                            "app_version": AppUpdateService.shared.getCurrentAppVersion(),
                            "network_connected": NetworkMonitorService.shared.isConnected,
                            "connection_type": NetworkMonitorService.shared.connectionType.displayName
                        ])
                        // 세션 시간 추적을 위해 UserDefaults에 시작 시간 저장
                        UserDefaults.standard.set(sessionStartTime.timeIntervalSince1970, forKey: "session_start_time")
                    }
                    
                    // 앱 종료 시 세션 추적 (NotificationCenter를 통해)
                    NotificationCenter.default.addObserver(
                        forName: UIApplication.willResignActiveNotification,
                        object: nil,
                        queue: .main
                    ) { _ in
                        // 세션 종료 시간 계산
                        if let startTimeInterval = UserDefaults.standard.object(forKey: "session_start_time") as? Double {
                            let startTime = Date(timeIntervalSince1970: startTimeInterval)
                            let sessionDuration = Date().timeIntervalSince(startTime)
                            
                            Analytics.logEvent("app_session_end", parameters: [
                                "session_duration_seconds": sessionDuration,
                                "user_logged_in": AuthManager.shared.isLoggedIn
                            ])
                        }
                    }
                }
        }
        .modelContainer(for: [
            CharacterModel.self,
            DailyTask.self,
            RaidGate.self
        ], isAutosaveEnabled: true) { result in
            print("🔵 ModelContainer 초기화 완료")
            switch result {
            case .success(let container):
                // Model Context 설정
                DataSyncManager.shared.setModelContext(container.mainContext)
                
                // 필요한 마이그레이션 수행
                DataMigrationService.shared.performMigrationIfNeeded(modelContext: container.mainContext)
                RaidDataMigrationService.shared.checkAndPerformMigrations(modelContext: container.mainContext)
                
                // 네트워크 콜백 설정
                setupNetworkCallbacks(modelContext: container.mainContext)
                
                // 로그인 상태라면 로컬 우선 동기화 시작
                if AuthManager.shared.isLoggedIn && NetworkMonitorService.shared.isConnected {
                    Task {
                        // 동기화 전략 명시적 설정
                        DataSyncManager.shared.syncStrategy = .localOverCloud
                        
                        // 항상 로컬->서버 방향으로 동기화
                        await DataSyncManager.shared.uploadToServer()
                    }
                }
            case .failure(let error):
                Logger.error("ModelContainer 생성 실패: \(error)")
                errorHandlingService.handleError(error, source: .database)
            }
        }
    }
    
    // 로컬 우선 동기화 메서드 추가
    private func performLocalPrioritySync() async {
        guard let modelContext = DataSyncManager.shared.modelContext,
              NetworkMonitorService.shared.isConnected,
              AuthManager.shared.isLoggedIn else {
            return
        }
        
        // 사용자에게 알림 없이 항상 로컬 우선으로 동기화
        DataSyncManager.shared.syncStrategy = .localOverCloud
        
        // 동기화 전에 충돌 해결 상태 미리 설정
        await MainActor.run {
            DataSyncManager.shared.hasConflicts = false
            DataSyncManager.shared.conflictsResolved = true
        }
        
        // 직접 uploadToServer 호출하여 로컬->서버 동기화 실행
        let success = await DataSyncManager.shared.uploadToServer()
        
        Logger.info("앱 시작 시 로컬 우선 동기화 완료: \(success ? "성공" : "실패")")
    }
    
    // 앱 초기화 시 호출
    private func setupPeriodicSync() {
        // 5분마다 한 번씩 변경사항이 있으면 동기화
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            if AuthManager.shared.isLoggedIn &&
                DataSyncManager.shared.hasPendingChanges &&
                NetworkMonitorService.shared.isConnected {
                Task {
                    _ = await DataSyncManager.shared.pushToCloud()
                }
            }
        }
    }
    
    class AppDelegate: NSObject, UIApplicationDelegate {
        func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
            return true
        }
        
        // iOS 9 이상에서 구글 로그인 URL 처리를 위해 필요
        func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
            return GIDSignIn.sharedInstance.handle(url)
        }
    }
    
    // 로그 시스템 초기화
    private func setupLoggingSystem() {
#if DEBUG
        // 디버그 모드에서는 자세한 로그 활성화
#else
        // 릴리스 모드에서는 중요 로그만 활성화
#endif
    }
    
    // 전역 새로고침 수행
    private func performGlobalRefresh() async {
        // 네트워크 연결 확인
        guard networkMonitor.isConnected else {
            errorHandlingService.handleError(
                DataSyncError.networkUnavailable,
                source: .network
            )
            return
        }
        
        do {
            // 로그인 상태이면 데이터 동기화
            if authManager.isLoggedIn {
                _ = await DataSyncManager.shared.performManualSync()
            }
            
            // 일일/주간 리셋 체크 - 여기서 접근 가능한 modelContext 사용
            if let modelContext = DataSyncManager.shared.modelContext {
                TaskResetManager.shared.checkAndResetTasks(modelContext: modelContext)
            }
        } catch {
            errorHandlingService.handleError(error, source: .sync)
        }
    }
    
    // 네트워크 콜백 설정
    private func setupNetworkCallbacks(modelContext: ModelContext) {
        _ = networkMonitor.onConnectionRestored {
            Logger.info("네트워크 연결 복구됨 - 자동 동기화 시작")
            
            // 로그인 상태이고 변경 사항이 있는 경우에만 자동 동기화
            if authManager.isLoggedIn && DataSyncManager.shared.hasPendingChanges {
                Task {
                    // 최대 3번 재시도
                    var retryCount = 0
                    var success = false
                    
                    while !success && retryCount < 3 {
                        success = await DataSyncManager.shared.uploadToServer()
                        
                        if !success {
                            // 재시도 간격 점진적 증가
                            try? await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(retryCount)) * 1_000_000_000))
                            retryCount += 1
                        }
                    }
                }
            }
        }
    }
    
    // 앱 생명주기 핸들러 설정
    private func setupAppLifecycleHandlers() {
        // foreground로 돌아올 때 일일/주간 리셋 체크
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            if let modelContext = DataSyncManager.shared.modelContext {
                TaskResetManager.shared.checkResetOnForeground(modelContext: modelContext)
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            // 앱 종료 직전 중요 설정 강제 저장
            let repChar = AuthManager.shared.representativeCharacter
            UserDefaults.standard.set(repChar, forKey: "representativeCharacter")
            
            if AuthManager.shared.userId != "" {
                UserDefaults.standard.set(repChar, forKey: "representativeCharacter_\(AuthManager.shared.userId)")
            }
        }
        
        // 앱이 포그라운드로 돌아올 때 친구 리스너가 작동 중인지 확인
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            if authManager.isLoggedIn {
                friendsService.setupListeners()
            }
        }
        
        // 백그라운드로 갈 때 데이터 동기화
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            if authManager.isLoggedIn && DataSyncManager.shared.hasPendingChanges && networkMonitor.isConnected {
                // 먼저 변수 선언
                var taskID = UIBackgroundTaskIdentifier.invalid
                
                // 그 다음 beginBackgroundTask 호출
                taskID = UIApplication.shared.beginBackgroundTask {
                    // 시간 제한에 도달했을 때 실행되는 핸들러
                    UIApplication.shared.endBackgroundTask(taskID)
                }
                
                Task {
                    do {
                        var success = false
                        var retryCount = 0
                        
                        while !success && retryCount < 3 && DataSyncManager.shared.hasPendingChanges {
                            success = await DataSyncManager.shared.uploadToServer()
                            retryCount += 1
                            
                            if !success && retryCount < 3 {
                                try await Task.sleep(nanoseconds: 500_000_000) // 0.5초 대기
                            }
                        }
                    } catch {
                        Logger.error("백그라운드 동기화 실패", error: error)
                    }
                    
                    // 항상 백그라운드 작업 완료 처리
                    await MainActor.run {
                        UIApplication.shared.endBackgroundTask(taskID)
                    }
                }
            }
        }
    }
}

// 앱 전체 새로고침 액션을 위한 환경 값
struct RefreshActionKey: EnvironmentKey {
    static let defaultValue = RefreshAction {}
}

extension EnvironmentValues {
    var refresh: RefreshAction {
        get { self[RefreshActionKey.self] }
        set { self[RefreshActionKey.self] = newValue }
    }
}

struct RefreshAction {
    var action: () -> Void
    
    func callAsFunction() {
        action()
    }
}
