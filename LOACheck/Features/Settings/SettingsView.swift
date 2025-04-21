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
    @ObservedObject private var themeManager = ThemeManager.shared
    
    // 환경 객체
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var errorService: ErrorHandlingService
    @ObservedObject private var dataSyncManager = DataSyncManager.shared
    @ObservedObject private var networkMonitor = NetworkMonitorService.shared
    @Environment(\.modelContext) private var modelContext
    
    // 캐릭터 목록 쿼리
    @Query(sort: \CharacterModel.level, order: .reverse) var characters: [CharacterModel]
    
    private func buildSettingsContent() -> some View {
        Group {
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
            
            buildAdditionalSettingsContent() // 추가 섹션을 위한 함수 호출
        }
    }
    
    // 나머지 섹션을 위한 추가 함수
    private func buildAdditionalSettingsContent() -> some View {
        Group {
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
            
            // 법적 고지 섹션
            LegalSectionView()
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                buildSettingsContent()
            }
            .navigationTitle("설정")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        ThemeManager.shared.isDarkMode.toggle()
                    }) {
                        ZStack {
                            // 항상 같은 크기의 프레임 유지
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.clear)
                                .frame(width: 36, height: 36)
                            
                            // 아이콘만 변경되도록 처리
                            Image(systemName: ThemeManager.shared.isDarkMode ? "sun.max.fill" : "moon.fill")
                                .imageScale(.large)
                                .font(.system(size: 20)) // 고정된 크기 지정
                                .foregroundColor(ThemeManager.shared.isDarkMode ? .yellow : .blue)
                        }
                    }
                    .buttonStyle(PlainButtonStyle()) // 기본 버튼 스타일 제거
                    // 아이콘 색상에만 애니메이션 적용, 크기나 위치는 제외
                    .animation(.spring(response: 0.3, dampingFraction: 0.7).speed(1.5), value: ThemeManager.shared.isDarkMode)
                }
            }
            .alert("알림", isPresented: $isShowingAlert) {
                Button("확인") { }
            } message: {
                Text(alertMessage)
            }
            .scrollDismissesKeyboard(.interactively)
            .overlay(OfflineOverlayView())
        }
        .alert("데이터 초기화 확인", isPresented: $isShowingResetConfirmation) {
            Button("취소", role: .cancel) { }
            Button("초기화", role: .destructive) {
                resetAllData()
            }
        } message: {
            Text("모든 캐릭터 데이터가 영구적으로 삭제됩니다.\n이 작업은 되돌릴 수 없습니다.")
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
                
                // 로컬 데이터 확인을 위해 ModelContext의 fetchCount 사용
                let localDescriptor = FetchDescriptor<CharacterModel>()
                let hasLocalData = try modelContext.fetchCount(localDescriptor) > 0
                
                // 클라우드 데이터 확인
                let cloudData = try await FirebaseRepository.shared.fetchCharacters()
                let hasCloudData = !cloudData.isEmpty
                
                if hasLocalData {
                    // 로컬 데이터가 있으면 무조건 서버로 업로드 (충돌 검사 없이)
                    _ = await dataSyncManager.pushToCloud()
                    await MainActor.run {
                        isDataSyncing = false
                    }
                } else if hasCloudData {
                    // 로컬 데이터가 없고 클라우드 데이터만 있으면 다운로드
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
