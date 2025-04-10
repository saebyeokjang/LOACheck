//
//  SettingsView.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 3/20/25.
//

import SwiftUI
import SwiftData
import FirebaseFirestore
import FirebaseAuth

// MARK: - 메인 설정 뷰
struct SettingsView: View {
    // 공유 상태 변수
    @AppStorage("apiKey") private var apiKey: String = ""
    @State private var isShowingAlert = false
    @State private var alertMessage = ""
    @State private var isShowingResetConfirmation = false
    @State private var showSignIn = false
    @State private var showSignOut = false
    @State private var showRepCharacterEditor = false
    @State private var showDataSyncChoiceAlert = false
    @State private var showSyncStrategySheet = false
    @State private var isDataSyncing = false
    
    // 환경 객체
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var errorService: ErrorHandlingService
    @ObservedObject private var dataSyncManager = DataSyncManager.shared
    @ObservedObject private var networkMonitor = NetworkMonitorService.shared
    @Environment(\.modelContext) private var modelContext
    
    // 캐릭터 목록 쿼리
    @Query(sort: \CharacterModel.level, order: .reverse) var characters: [CharacterModel]
    
    var body: some View {
        NavigationStack {
            Form {
                // 계정 섹션
                AccountSectionView(
                    showSignIn: $showSignIn,
                    showSignOut: $showSignOut,
                    showRepCharacterEditor: $showRepCharacterEditor
                )
                
                // 로그인 시에만 동기화 관련 섹션 표시
                if authManager.isLoggedIn {
                    DataSyncSectionView(
                        dataSyncManager: dataSyncManager,
                        networkMonitor: networkMonitor,
                        isDataSyncing: $isDataSyncing,
                        showSyncStrategySheet: $showSyncStrategySheet,
                        alertMessage: $alertMessage,
                        isShowingAlert: $isShowingAlert
                    )
                }
                
                // API 설정 섹션
                APIKeySectionView(
                    apiKey: $apiKey,
                    alertMessage: $alertMessage,
                    isShowingAlert: $isShowingAlert
                )
                
                // 원정대 관리 섹션
                RosterManagementSectionView(
                    apiKey: apiKey,
                    authManager: authManager,
                    networkMonitor: networkMonitor,
                    modelContext: modelContext,
                    dataSyncManager: dataSyncManager,
                    errorService: errorService,
                    alertMessage: $alertMessage,
                    isShowingAlert: $isShowingAlert
                )
                
                // 다른 원정대 추가 섹션
                AdditionalRosterSectionView(
                    apiKey: apiKey,
                    authManager: authManager,
                    networkMonitor: networkMonitor,
                    modelContext: modelContext,
                    dataSyncManager: dataSyncManager,
                    errorService: errorService,
                    alertMessage: $alertMessage,
                    isShowingAlert: $isShowingAlert
                )
                
                // 앱 정보 섹션
                AppInfoSectionView(
                    networkMonitor: networkMonitor,
                    errorService: errorService,
                    alertMessage: $alertMessage,
                    isShowingAlert: $isShowingAlert
                )
                
                // 데이터 관리 섹션
                DataManagementSectionView(
                    isShowingResetConfirmation: $isShowingResetConfirmation
                )
                
                // 개발자 정보 섹션
                DeveloperInfoSectionView()
            }
            .navigationTitle("설정")
            .alert("알림", isPresented: $isShowingAlert) {
                Button("확인") { }
            } message: {
                Text(alertMessage)
            }
            .scrollDismissesKeyboard(.interactively)
            .overlay(OfflineOverlayView())
            .actionSheet(isPresented: $showSyncStrategySheet) {
                ActionSheet(
                    title: Text("동기화 방법 선택"),
                    message: Text("데이터 충돌 시 어떤 방법으로 해결할지 선택하세요"),
                    buttons: [
                        .default(Text("병합 (권장)")) {
                            dataSyncManager.syncStrategy = .merge
                        },
                        .default(Text("로컬 우선")) {
                            dataSyncManager.syncStrategy = .localOverCloud
                        },
                        .default(Text("클라우드 우선")) {
                            dataSyncManager.syncStrategy = .cloudOverLocal
                        },
                        .cancel(Text("취소"))
                    ]
                )
            }
        }
        .alert("데이터 초기화 확인", isPresented: $isShowingResetConfirmation) {
            Button("취소", role: .cancel) { }
            Button("초기화", role: .destructive) {
                resetAllData()
            }
        } message: {
            Text("모든 캐릭터 데이터가 영구적으로 삭제됩니다.\n이 작업은 되돌릴 수 없습니다.\n계속하시겠습니까?")
        }
        .alert("로그아웃", isPresented: $showSignOut) {
            Button("취소", role: .cancel) { }
            Button("로그아웃", role: .destructive) {
                logOut()
            }
        } message: {
            Text("로그아웃 하시겠습니까?\n비로그인 모드로 전환됩니다.")
        }
        .alert("데이터 동기화 선택", isPresented: $showDataSyncChoiceAlert) {
            Button("서버 데이터 사용") {
                Task {
                    await dataSyncManager.pullFromCloud()
                }
            }
            Button("로컬 데이터 사용") {
                Task {
                    await dataSyncManager.pushToCloud()
                }
            }
            Button("병합 (권장)") {
                dataSyncManager.syncStrategy = .merge
                Task {
                    await dataSyncManager.performManualSync()
                }
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("로컬과 서버 모두 데이터가 있습니다.\n어떤 데이터를 사용하시겠습니까?")
        }
        .sheet(isPresented: $showSignIn) {
            SignInView(isPresented: $showSignIn)
                .onDisappear {
                    if authManager.isLoggedIn {
                        checkSyncAfterLogin()
                    }
                }
        }
        .sheet(isPresented: $showRepCharacterEditor) {
            RepCharacterEditorView(
                characters: characters,
                authManager: authManager,
                showRepCharacterEditor: $showRepCharacterEditor,
                alertMessage: $alertMessage,
                isShowingAlert: $isShowingAlert
            )
        }
    }
    
    // MARK: - 남아있는 핵심 헬퍼 함수들
    
    // 로그인 후 동기화 처리
    private func checkSyncAfterLogin() {
        Task {
            do {
                isDataSyncing = true
                
                // DataSyncManager.swift에서 사용 가능한 메서드 확인
                // 로컬 데이터 확인을 위해 ModelContext의 fetchCount 사용
                let localDescriptor = FetchDescriptor<CharacterModel>()
                let hasLocalData = try modelContext.fetchCount(localDescriptor) > 0
                
                // 클라우드 데이터 확인
                let cloudData = try await FirebaseRepository.shared.fetchCharacters()
                let hasCloudData = !cloudData.isEmpty
                
                if hasLocalData && hasCloudData {
                    await MainActor.run {
                        isDataSyncing = false
                        showDataSyncChoiceAlert = true
                    }
                } else if hasCloudData {
                    let success = await dataSyncManager.pullFromCloud()
                    await MainActor.run {
                        isDataSyncing = false
                        if success {
                            alertMessage = "서버에서 데이터를 가져왔습니다."
                        } else {
                            alertMessage = "서버 데이터 가져오기에 실패했습니다."
                        }
                        isShowingAlert = true
                    }
                } else if hasLocalData {
                    let success = await dataSyncManager.pushToCloud()
                    await MainActor.run {
                        isDataSyncing = false
                        if success {
                            alertMessage = "로컬 데이터를 서버에 업로드했습니다."
                        } else {
                            alertMessage = "데이터 업로드에 실패했습니다."
                        }
                        isShowingAlert = true
                    }
                } else {
                    await MainActor.run {
                        isDataSyncing = false
                    }
                }
            } catch {
                await MainActor.run {
                    isDataSyncing = false
                    errorService.handleError(error, source: .sync)
                }
            }
        }
    }
    
    // 모든 데이터 초기화
    private func resetAllData() {
        Task {
            do {
                guard let modelContext = DataSyncManager.shared.modelContext else {
                    throw NSError(domain: "App", code: 1, userInfo: [NSLocalizedDescriptionKey: "Model context is nil"])
                }
                
                try modelContext.safeDeleteAll(of: DailyTask.self)
                try modelContext.safeDeleteAll(of: RaidGate.self)
                try modelContext.safeDeleteAll(of: CharacterModel.self)
                
                if authManager.isLoggedIn && networkMonitor.isConnected {
                    let repository = DataRepositoryFactory.getRepository(modelContext: modelContext)
                    try await repository.deleteAllCharacters()
                } else if authManager.isLoggedIn {
                    dataSyncManager.markLocalChanges()
                }
                
                await MainActor.run {
                    alertMessage = "모든 데이터가 초기화되었습니다."
                    isShowingAlert = true
                }
            } catch {
                await MainActor.run {
                    errorService.handleError(error, source: .database)
                    alertMessage = "데이터 초기화 중 오류가 발생했습니다: \(error.localizedDescription)"
                    isShowingAlert = true
                }
            }
        }
    }
    
    // 로그아웃
    private func logOut() {
        Task {
            let success = await authManager.signOut()
            
            if success {
                await MainActor.run {
                    alertMessage = "로그아웃되었습니다."
                    isShowingAlert = true
                }
            } else {
                await MainActor.run {
                    if let error = authManager.error {
                        errorService.handleError(error, source: .authentication)
                    } else {
                        alertMessage = "로그아웃 중 오류가 발생했습니다."
                        isShowingAlert = true
                    }
                }
            }
        }
    }
}
