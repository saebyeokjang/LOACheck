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

@main
struct LOACheckApp: App {
    // 인증 및 서비스 관리자 초기화
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var errorHandlingService = ErrorHandlingService.shared
    @StateObject private var networkMonitor = NetworkMonitorService.shared
    
    // 앱 시작 시 초기화 플래그
    @State private var isInitialized = false
    
    init() {
        // Firebase 초기화
        FirebaseApp.configure()
        
        // 로그 시스템 초기화
        setupLoggingSystem()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(errorHandlingService)
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
                        isInitialized = true
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
                
                // 초기 데이터 마이그레이션 수행
                DataMigrationService.shared.performMigrationIfNeeded(modelContext: container.mainContext)
                
                // 레이드 데이터 마이그레이션
                RaidDataMigrationService.shared.checkAndPerformMigrations(modelContext: container.mainContext)
                
                // 네트워크 연결 복구 시 동기화 콜백 등록
                setupNetworkCallbacks(modelContext: container.mainContext)
            case .failure(let error):
                Logger.error("ModelContainer 생성 실패: \(error)")
                errorHandlingService.handleError(error, source: .database)
                print("ModelContainer 초기화 상태: \(result)")
            }
        }
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
        // 네트워크 연결 복구 시 자동 동기화
        _ = networkMonitor.onConnectionRestored {
            Logger.info("네트워크 연결 복구됨 - 자동 동기화 시작")
            
            // 로그인 상태이고 변경 사항이 있는 경우에만 자동 동기화
            if authManager.isLoggedIn && DataSyncManager.shared.hasPendingChanges {
                Task {
                    await DataSyncManager.shared.performManualSync()
                }
            }
            
            // 일일/주간 리셋 체크
            TaskResetManager.shared.checkAndResetTasks(modelContext: modelContext)
        }
        
        // 네트워크 연결 끊김 시 오프라인 모드 표시
        _ = networkMonitor.onConnectionLost {
            Logger.info("네트워크 연결 끊김 - 오프라인 모드로 전환")
            // 여기서는 경고만 표시하도록 하고, 실제 작업은 네트워크 상태에 따라 UI에서 처리
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
        
        // 백그라운드로 갈 때 데이터 동기화
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            if authManager.isLoggedIn && DataSyncManager.shared.hasPendingChanges && networkMonitor.isConnected {
                Task {
                    await DataSyncManager.shared.pushToCloud()
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
