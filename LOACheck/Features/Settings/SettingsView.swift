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

struct SettingsView: View {
    @AppStorage("apiKey") private var apiKey: String = ""
    @State private var tempApiKey: String = ""
    
    @AppStorage("representativeCharacter") private var representativeCharacter: String = ""
    @State private var tempRepChar: String = ""
    
    // 임시 캐릭터 이름 저장용 상태 변수
    @State private var otherCharacterName: String = ""
    @State private var isFetchingOtherRoster: Bool = false
    
    // 키보드 제어를 위한 FocusState 추가
    @FocusState private var isApiKeyFocused: Bool
    @FocusState private var isCharNameFocused: Bool
    
    @State private var isShowingAlert = false
    @State private var alertMessage = ""
    @State private var isRefreshing = false
    @State private var isShowingResetConfirmation = false
    @State private var showUpdateAlert = false
    @State private var latestVersion = ""
    @State private var releaseNotes: String? = nil
    @AppStorage("skipVersion") private var skipVersion = ""
    @Environment(\.modelContext) private var modelContext
    
    // 인증 관련 상태
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var errorService: ErrorHandlingService
    @ObservedObject private var dataSyncManager = DataSyncManager.shared
    @ObservedObject private var networkMonitor = NetworkMonitorService.shared
    @State private var showSignIn = false
    @State private var showSignOut = false
    @State private var isDataSyncing = false
    
    // 캐릭터 목록 쿼리 (대표 캐릭터 이름 표시용)
    @Query(sort: \CharacterModel.level, order: .reverse) var characters: [CharacterModel]
    
    // 대표 캐릭터 이름 계산 속성
    private var displayName: String {
        // 1. 대표 캐릭터 설정 값이 있고 로그인 상태라면 해당 값 사용
        if !representativeCharacter.isEmpty && authManager.isLoggedIn {
            return representativeCharacter
        }
        
        // 2. 캐릭터가 있다면 가장 높은 레벨의 캐릭터 이름 사용
        if let mainCharacter = characters.first {
            return mainCharacter.name
        }
        
        // 3. 기본값 반환
        return authManager.displayName
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // 인증 섹션
                Section(header: Text("계정")) {
                    if authManager.isLoggedIn {
                        // 로그인 상태
                        HStack {
                            Text("로그인 상태")
                            Spacer()
                            
                            if authManager.isLoggedIn {
                                Text("온라인")
                                    .foregroundColor(.green)
                            } else {
                                Text("오프라인")
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // 로그인 된 경우에만 사용자 정보 표시
                        if authManager.isLoggedIn {
                            HStack {
                                Text("계정")
                                Spacer()
                                Text(authManager.email)
                                    .foregroundColor(.secondary)
                            }
                            
                            // 대표 캐릭터 정보
                            HStack {
                                Text("대표 캐릭터")
                                Spacer()
                                Text(authManager.representativeCharacter.isEmpty ? "미설정" : authManager.representativeCharacter)
                                    .foregroundColor(authManager.representativeCharacter.isEmpty ? .orange : .blue)
                            }
                        }
                        
                        // 데이터 동기화 상태
                        HStack {
                            Text("동기화 상태")
                            Spacer()
                            
                            if dataSyncManager.isSyncing {
                                HStack {
                                    Text("동기화 중...")
                                    ProgressView()
                                        .controlSize(.small)
                                }
                                .foregroundColor(.blue)
                            } else if dataSyncManager.hasPendingChanges {
                                HStack {
                                    Text("동기화 필요")
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundColor(.orange)
                                }
                            } else {
                                Text("동기화됨")
                                    .foregroundColor(.green)
                            }
                        }
                        
                        // 네트워크 상태
                        HStack {
                            Text("네트워크")
                            Spacer()
                            NetworkStatusIndicatorView()
                        }
                        
                        // 로그아웃 버튼
                        Button(action: {
                            showSignOut = true
                        }) {
                            Text("로그아웃")
                                .foregroundColor(.red)
                        }
                    } else {
                        // 비로그인 상태
                        HStack {
                            Text("로그인 상태")
                            Spacer()
                            Text("로그인하지 않음")
                                .foregroundColor(.secondary)
                        }
                        
                        // 로그인 버튼
                        Button(action: {
                            showSignIn = true
                        }) {
                            Text("로그인")
                                .foregroundColor(.blue)
                        }
                        
                        Text("로그인하면 친구와 진행 상황을 공유할 수 있습니다")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // 데이터 동기화 섹션 (로그인 상태일 때만 표시)
                if authManager.isLoggedIn {
                    Section(header: Text("데이터 동기화"), footer: Text("캐릭터 정보는 서버에 자동으로 저장됩니다.")) {
                        // 자동 동기화 토글
                        Toggle("자동 동기화", isOn: $dataSyncManager.useAutoSync)
                            .onChange(of: dataSyncManager.useAutoSync) { oldValue, newValue in
                                UserDefaults.standard.set(newValue, forKey: "useAutoSync")
                            }
                        
                        // 수동 업로드 버튼
                        Button(action: {
                            Task {
                                isDataSyncing = true
                                let success = await dataSyncManager.uploadToServer()
                                isDataSyncing = false
                                
                                if success {
                                    alertMessage = "데이터가 성공적으로 서버에 업로드되었습니다."
                                } else if let error = dataSyncManager.syncError {
                                    alertMessage = "업로드 중 오류가 발생했습니다: \(error.localizedDescription)"
                                } else {
                                    alertMessage = "업로드 중 오류가 발생했습니다."
                                }
                                isShowingAlert = true
                            }
                        }) {
                            HStack {
                                Text("서버에 데이터 저장")
                                Spacer()
                                if isDataSyncing {
                                    ProgressView()
                                        .controlSize(.small)
                                }
                            }
                        }
                        .disabled(isDataSyncing || !networkMonitor.isConnected)
                        
                        // 서버에서 복구 버튼
                        Button(action: {
                            confirmAction(
                                message: "서버에서 데이터를 복구하시겠습니까? 현재 기기의 데이터는 모두 삭제되고 서버의 데이터로 대체됩니다.",
                                action: {
                                    Task {
                                        isDataSyncing = true
                                        let success = await dataSyncManager.recoverFromServer()
                                        isDataSyncing = false
                                        
                                        if success {
                                            alertMessage = "서버에서 데이터가 성공적으로 복구되었습니다."
                                        } else if let error = dataSyncManager.syncError {
                                            alertMessage = "복구 중 오류가 발생했습니다: \(error.localizedDescription)"
                                        } else {
                                            alertMessage = "복구할 데이터가 없거나 오류가 발생했습니다."
                                        }
                                        isShowingAlert = true
                                    }
                                }
                            )
                        }) {
                            Text("서버에서 데이터 복구")
                                .foregroundColor(.orange)
                        }
                        .disabled(isDataSyncing || !networkMonitor.isConnected)
                    }
                }
                
                Section(header: Text("로스트아크 API 설정"), footer: Text("API키 발급받으러 가기\nhttps://developer-lostark.game.onstove.com")) {
                    SecureField("API 키 입력", text: $tempApiKey)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($isApiKeyFocused)
                        .onAppear {
                            tempApiKey = apiKey
                        }
                    
                    TextField("대표 캐릭터 이름", text: $tempRepChar)
                        .autocorrectionDisabled()
                        .focused($isCharNameFocused)
                        .onAppear {
                            tempRepChar = authManager.representativeCharacter
                        }
                        .submitLabel(.done)
                    
                    Button(action: {
                        // 캐릭터 이름이 비어있지 않은 경우에만 진행
                        if !tempRepChar.isEmpty {
                            // 캐릭터 존재 여부 확인 후 설정
                            checkAndSetRepresentativeCharacter()
                        }
                    }) {
                        Text("대표 캐릭터 설정")
                    }
                    .disabled(tempRepChar.isEmpty || isRefreshing)
                    
                    Button(action: testAndFetchCharacters) {
                        HStack {
                            Text("캐릭터 정보 불러오기")
                            if isRefreshing {
                                Spacer()
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                    }
                    .disabled(apiKey.isEmpty || representativeCharacter.isEmpty || isRefreshing || !networkMonitor.isConnected)
                    
                    Text("다른 원정대 추가하기")
                        .font(.headline)
                        .padding(.top, 4)
                    
                    TextField("캐릭터 이름 입력", text: $otherCharacterName)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                    
                    Button(action: fetchAdditionalRoster) {
                        HStack {
                            Text("해당 캐릭터의 원정대 추가하기")
                            if isFetchingOtherRoster {
                                Spacer()
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                    }
                    .disabled(apiKey.isEmpty || otherCharacterName.isEmpty || isFetchingOtherRoster || !networkMonitor.isConnected)
                }
                
                Section(header: Text("앱 정보")) {
                    HStack {
                        Text("앱 버전")
                        Spacer()
                        Text(AppUpdateService.shared.getCurrentAppVersion())
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("리셋 시간")
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("일일: 매일 06:00")
                            Text("주간: 매주 수요일 06:00")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    
                    Button(action: checkForUpdates) {
                        HStack {
                            Text("업데이트 확인")
                            if isRefreshing {
                                Spacer()
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                    }
                    .disabled(isRefreshing || !networkMonitor.isConnected)
                }
                
                Section(header: Text("데이터 관리")) {
                    Button(action: {
                        // 확인 알림 표시
                        isShowingResetConfirmation = true
                    }) {
                        Text("모든 데이터 초기화")
                            .foregroundColor(.red)
                    }
                }
                
                Section(header: Text("만든 사람")) {
                    Link("개발자에게 피드백 보내기", destination: URL(string: "mailto:dev.saebyeok@gmail.com?subject=LOACheck 피드백")!)
                    Text("실리안 • 기상술사김새벽")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("설정")
            .alert("알림", isPresented: $isShowingAlert) {
                Button("확인") { }
            } message: {
                Text(alertMessage)
            }
            // 키보드 입력모드 수정
            .scrollDismissesKeyboard(.interactively)
            .overlay(OfflineOverlayView())
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
        .sheet(isPresented: $showUpdateAlert) {
            ZStack {
                Color(.systemBackground).edgesIgnoringSafeArea(.all)
                
                UpdateAlertView(
                    isPresented: $showUpdateAlert,
                    currentVersion: AppUpdateService.shared.getCurrentAppVersion(),
                    latestVersion: latestVersion,
                    releaseNotes: releaseNotes,
                    onUpdate: {
                        openAppStore()
                    },
                    onLater: {
                        // 나중에 버튼
                    }
                )
                .padding()
            }
        }
        .sheet(isPresented: $showSignIn) {
            SignInView(isPresented: $showSignIn)
                .onDisappear {
                    // 로그인 완료 후 데이터 마이그레이션 수행
                    if authManager.isLoggedIn {
                        DataMigrationService.shared.performInitialMigrationAfterLogin(modelContext: modelContext)
                        // 대표 캐릭터가 있으면 표시 이름으로 설정
                        if !authManager.representativeCharacter.isEmpty {
                            authManager.updateDisplayNameToRepCharacter()
                        }
                    }
                }
        }
    }
    
    // 확인 대화상자 표시
    private func confirmAction(message: String, action: @escaping () -> Void) {
        alertMessage = message
        isShowingAlert = true
        // 확인 버튼 액션 지정 - 현재 Alert API 제한으로 인해 커스텀 알림 뷰 필요
        // 이 부분은 간단한 구현을 위해 생략
    }
    
    private func checkAndSetRepresentativeCharacter() {
        isRefreshing = true
        
        Task {
            // 1. 로스트아크 API를 통해 캐릭터 존재 여부 확인
            let result = await LostArkAPIService.shared.validateCharacter(name: tempRepChar, apiKey: apiKey)
            
            await MainActor.run {
                switch result {
                case .success(let exists):
                    if exists {
                        // 이제 기존 로직 진행 - 현재 캐릭터 목록에서 같은 이름을 가진 캐릭터 확인
                        let isMine = characters.contains { $0.name == tempRepChar }
                        
                        if isMine {
                            // 내 캐릭터인 경우, 이제 서버에서 중복 확인 후 대표 캐릭터로 설정
                            Task {
                                do {
                                    let success = try await authManager.setRepresentativeCharacter(tempRepChar)
                                    
                                    await MainActor.run {
                                        if success {
                                            alertMessage = "대표 캐릭터가 '\(tempRepChar)'(으)로 설정되었습니다."
                                        } else {
                                            alertMessage = "'\(tempRepChar)'는 이미 다른 사용자가 대표 캐릭터로 사용 중입니다."
                                        }
                                        isShowingAlert = true
                                    }
                                } catch {
                                    await MainActor.run {
                                        alertMessage = "대표 캐릭터 설정 중 오류가 발생했습니다: \(error.localizedDescription)"
                                        isShowingAlert = true
                                    }
                                }
                            }
                        } else {
                            // 존재하지만 내 캐릭터가 아닌 경우
                            alertMessage = "'\(tempRepChar)'는 내 캐릭터가 아닙니다. 먼저 캐릭터 정보를 불러와주세요."
                            isShowingAlert = true
                        }
                    } else {
                        // 캐릭터가 존재하지 않음
                        alertMessage = "해당 캐릭터를 찾을 수 없습니다. 캐릭터 이름을 다시 확인해주세요."
                        isShowingAlert = true
                    }
                    
                case .failure(let error):
                    alertMessage = "캐릭터 확인 중 오류가 발생했습니다: \(error.userFriendlyMessage)"
                    isShowingAlert = true
                }
                
                isRefreshing = false
            }
        }
    }
    
    // 다른 원정대의 캐릭터 정보를 불러오는 함수
    private func fetchAdditionalRoster() {
        guard !apiKey.isEmpty else {
            alertMessage = "API 키를 먼저 입력해주세요."
            isShowingAlert = true
            return
        }
        
        guard !otherCharacterName.isEmpty else {
            alertMessage = "추가할 캐릭터 이름을 입력해주세요."
            isShowingAlert = true
            return
        }
        
        guard networkMonitor.isConnected else {
            alertMessage = "오프라인 상태에서는 캐릭터 정보를 불러올 수 없습니다."
            isShowingAlert = true
            return
        }
        
        isFetchingOtherRoster = true
        
        Task {
            do {
                // 먼저 캐릭터 존재 여부 확인
                let validationResult = await LostArkAPIService.shared.validateCharacter(name: otherCharacterName, apiKey: apiKey)
                
                switch validationResult {
                case .success(let exists):
                    if !exists {
                        await MainActor.run {
                            isFetchingOtherRoster = false
                            alertMessage = "입력한 캐릭터를 찾을 수 없습니다. 캐릭터 이름을 다시 확인해주세요."
                            isShowingAlert = true
                        }
                        return
                    }
                    
                    // 캐릭터가 존재하면 해당 캐릭터의 원정대 정보 추가
                    let result = await LostArkAPIService.shared.fetchAdditionalRoster(
                        characterName: otherCharacterName,
                        apiKey: apiKey,
                        modelContext: modelContext
                    )
                    
                    await MainActor.run {
                        isFetchingOtherRoster = false
                        
                        switch result {
                        case .success(let count):
                            alertMessage = "'\(otherCharacterName)'의 원정대 캐릭터를 기존 데이터에 추가했습니다. (\(count)개)"
                            
                            // 로그인 상태면 데이터 동기화 필요 표시
                            if authManager.isLoggedIn {
                                dataSyncManager.markLocalChanges()
                            }
                            
                        case .failure(let error):
                            errorService.handleError(error, source: .api) {
                                // 재시도 액션
                                fetchAdditionalRoster()
                            }
                            alertMessage = "오류가 발생했습니다: \(error.userFriendlyMessage)"
                        }
                        
                        isShowingAlert = true
                    }
                    
                case .failure(let error):
                    await MainActor.run {
                        isFetchingOtherRoster = false
                        alertMessage = "API 오류: \(error.userFriendlyMessage)"
                        isShowingAlert = true
                    }
                }
            } catch {
                await MainActor.run {
                    isFetchingOtherRoster = false
                    errorService.handleError(error, source: .api)
                }
            }
        }
    }
    
    // 설정 저장 (API 키와 대표 캐릭터)
    private func saveSettings() {
        // 키보드 숨기기
        isApiKeyFocused = false
        isCharNameFocused = false
        
        // API 키 저장
        apiKey = tempApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let newRepChar = tempRepChar.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 캐릭터 이름이 변경된 경우에만 검증 진행
        if newRepChar != representativeCharacter && !newRepChar.isEmpty {
            // 캐릭터 존재 여부 확인은 checkAndSetRepresentativeCharacter 함수에 위임
            checkAndSetRepresentativeCharacter()
        } else {
            // API 키만 변경된 경우
            alertMessage = "API 키가 저장되었습니다."
            isShowingAlert = true
        }
    }
    
    // API 키 테스트 및 캐릭터 불러오기
    private func testAndFetchCharacters() {
        guard !apiKey.isEmpty else {
            alertMessage = "API 키를 먼저 입력해주세요."
            isShowingAlert = true
            return
        }
        
        guard !representativeCharacter.isEmpty else {
            alertMessage = "대표 캐릭터 이름을 먼저 입력해주세요."
            isShowingAlert = true
            return
        }
        
        guard networkMonitor.isConnected else {
            alertMessage = "오프라인 상태에서는 캐릭터 정보를 불러올 수 없습니다."
            isShowingAlert = true
            return
        }
        
        isRefreshing = true
        
        Task {
            do {
                // 1. 대표 캐릭터 존재 여부 먼저 확인
                let validationResult = await LostArkAPIService.shared.validateCharacter(name: representativeCharacter, apiKey: apiKey)
                
                switch validationResult {
                case .success(let exists):
                    if !exists {
                        await MainActor.run {
                            isRefreshing = false
                            alertMessage = "대표 캐릭터를 찾을 수 없습니다. 캐릭터 이름을 다시 확인해주세요."
                            isShowingAlert = true
                        }
                        return
                    }
                    
                    // 2. 캐릭터 정보 불러오기 (기존 데이터 초기화)
                    let result = await LostArkAPIService.shared.fetchCharacters(
                        apiKey: apiKey,
                        modelContext: modelContext,
                        clearExisting: true  // 기존 데이터 초기화 옵션
                    )
                    
                    await MainActor.run {
                        isRefreshing = false
                        
                        switch result {
                        case .success(let count):
                            alertMessage = "캐릭터 정보를 성공적으로 불러왔습니다. (\(count)개)"
                            
                            // 로그인 상태면 데이터 동기화 필요 표시
                            if authManager.isLoggedIn {
                                dataSyncManager.markLocalChanges()
                            }
                            
                        case .failure(let error):
                            errorService.handleError(error, source: .api) {
                                // 재시도 액션
                                testAndFetchCharacters()
                            }
                            alertMessage = "오류가 발생했습니다: \(error.userFriendlyMessage)"
                        }
                        
                        isShowingAlert = true
                    }
                    
                case .failure(let error):
                    await MainActor.run {
                        isRefreshing = false
                        alertMessage = "API 오류: \(error.userFriendlyMessage)"
                        isShowingAlert = true
                    }
                }
            } catch {
                await MainActor.run {
                    isRefreshing = false
                    errorService.handleError(error, source: .api)
                }
            }
        }
    }
    
    // 데이터 동기화
    private func syncData() {
        guard networkMonitor.isConnected else {
            alertMessage = "오프라인 상태에서는 동기화할 수 없습니다."
            isShowingAlert = true
            return
        }
        
        isDataSyncing = true
        
        Task {
            let success = await dataSyncManager.uploadToServer()
            
            await MainActor.run {
                isDataSyncing = false
                
                if success {
                    alertMessage = "데이터가 성공적으로 동기화되었습니다."
                } else if let error = dataSyncManager.syncError {
                    errorService.handleError(error, source: .sync) {
                        // 재시도 액션
                        syncData()
                    }
                } else {
                    alertMessage = "동기화 중 오류가 발생했습니다."
                }
                
                isShowingAlert = true
            }
        }
    }
    
    // 로그아웃
    private func logOut() {
        Task {
            let success = await authManager.signOut()
            
            if success {
                // 로그아웃 성공
                await MainActor.run {
                    alertMessage = "로그아웃되었습니다."
                    isShowingAlert = true
                }
            } else {
                // 로그아웃 실패
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
    
    // 모든 데이터 초기화
    private func resetAllData() {
        isRefreshing = true
        
        Task {
            do {
                // 1. 모델 컨텍스트 확인
                guard let modelContext = DataSyncManager.shared.modelContext else {
                    throw NSError(domain: "App", code: 1, userInfo: [NSLocalizedDescriptionKey: "Model context is nil"])
                }
                
                // 2. 각 모델 타입을 안전하게 삭제 (순서가 중요함)
                try modelContext.safeDeleteAll(of: DailyTask.self)
                try modelContext.safeDeleteAll(of: RaidGate.self)
                try modelContext.safeDeleteAll(of: CharacterModel.self)
                
                // 3. 클라우드 데이터도 삭제 (로그인 상태인 경우)
                if authManager.isLoggedIn && networkMonitor.isConnected {
                    let repository = DataRepositoryFactory.getRepository(modelContext: modelContext)
                    try await repository.deleteAllCharacters()
                } else if authManager.isLoggedIn {
                    // 오프라인이면 변경 사항 표시
                    dataSyncManager.markLocalChanges()
                }
                
                // 4. 작업 완료 후 UI 업데이트
                await MainActor.run {
                    isRefreshing = false
                    alertMessage = "모든 데이터가 초기화되었습니다."
                    isShowingAlert = true
                }
            } catch {
                // 오류 처리
                await MainActor.run {
                    isRefreshing = false
                    errorService.handleError(error, source: .database)
                    alertMessage = "데이터 초기화 중 오류가 발생했습니다: \(error.localizedDescription)"
                    isShowingAlert = true
                }
            }
        }
    }
    
    // 업데이트 확인
    func checkForUpdates() {
        guard networkMonitor.isConnected else {
            alertMessage = "오프라인 상태에서는 업데이트를 확인할 수 없습니다."
            isShowingAlert = true
            return
        }
        
        isRefreshing = true
        
        Task {
            // 현재 버전
            let currentVersion = AppUpdateService.shared.getCurrentAppVersion()
            
            // 최신 버전 정보 가져오기
            let result = await AppUpdateService.shared.checkForUpdate()
            
            await MainActor.run {
                isRefreshing = false
                
                switch result {
                case .success(let versionInfo):
                    latestVersion = versionInfo.latestVersion
                    releaseNotes = versionInfo.releaseNotes
                    
                    // 업데이트 필요성 확인
                    let updateAvailable = AppUpdateService.shared.isUpdateAvailable(
                        currentVersion: currentVersion,
                        latestVersion: latestVersion
                    )
                    
                    if updateAvailable {
                        // 사용자가 이 버전을 건너뛰기로 했는지 확인
                        if latestVersion != skipVersion {
                            showUpdateAlert = true
                        } else {
                            // 사용자가 이미 이 버전을 건너뛰기로 했음
                            alertMessage = "새 버전(v\(latestVersion))이 있지만 건너뛰기로 설정되었습니다."
                            isShowingAlert = true
                        }
                    } else {
                        alertMessage = "현재 최신 버전을 사용 중입니다. (v\(currentVersion))"
                        isShowingAlert = true
                    }
                    
                case .failure(let error):
                    errorService.handleError(error, source: .network) {
                        // 재시도 액션
                        checkForUpdates()
                    }
                    alertMessage = "업데이트 확인 중 오류가 발생했습니다: \(error.localizedDescription)"
                    isShowingAlert = true
                }
            }
        }
    }
    
    // 앱스토어 열기
    func openAppStore() {
        if let url = URL(string: "itms-apps://itunes.apple.com/app/id\(AppUpdateService.appID)") {
            UIApplication.shared.open(url)
        }
    }
}
