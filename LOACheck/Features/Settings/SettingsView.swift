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
    @State private var showSignIn = false
    @State private var showSignOut = false
    @State private var isDataSyncing = false
    @StateObject private var dataSyncManager = DataSyncManager.shared
    
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
                            Text(authManager.displayName)
                                .foregroundColor(.green)
                        }
                        
                        HStack {
                            Text("이메일")
                            Spacer()
                            Text(authManager.email)
                                .foregroundColor(.secondary)
                        }
                        
                        // 데이터 동기화 버튼
                        if dataSyncManager.hasPendingChanges {
                            HStack {
                                Text("동기화 필요")
                                Spacer()
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.orange)
                            }
                        }
                        
                        Button(action: syncData) {
                            HStack {
                                Text("데이터 동기화")
                                
                                if isDataSyncing {
                                    Spacer()
                                    ProgressView()
                                        .controlSize(.small)
                                }
                            }
                        }
                        .disabled(isDataSyncing)
                        
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
                
                Section(header: Text("로스트아크 API 설정"), footer: Text("로스트아크 개발자 포털 (https://developer-lostark.game.onstove.com) 에서 API 키를 발급받을 수 있습니다.")) {
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
                            tempRepChar = representativeCharacter
                        }
                        .submitLabel(.done) // 키보드 Return 버튼 레이블 설정
                    
                    Button(action: saveSettings) {
                        Text("설정 저장")
                    }
                    .disabled(tempApiKey.isEmpty || tempRepChar.isEmpty)
                    
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
                    .disabled(apiKey.isEmpty || representativeCharacter.isEmpty || isRefreshing)
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
                    .disabled(isRefreshing)
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
        }
    }
    
    // 설정 저장 (API 키와 대표 캐릭터)
    private func saveSettings() {
        // 키보드 숨기기
        isApiKeyFocused = false
        isCharNameFocused = false
        
        apiKey = tempApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        representativeCharacter = tempRepChar.trimmingCharacters(in: .whitespacesAndNewlines)
        uploadCharacterNameToFirestore(representativeCharacter)
    }
    
    func uploadCharacterNameToFirestore(_ characterName: String) {
        guard let user = Auth.auth().currentUser else {
            print("로그인된 유저가 없습니다.")
            alertMessage = "로그인이 필요합니다."
            isShowingAlert = true
            return
        }

        let db = Firestore.firestore()
        let docRef = db.collection("characterNames").document(characterName)

        // 캐릭터 중복 확인
        docRef.getDocument { document, error in
            if let error = error {
                print("문서 확인 실패: \(error.localizedDescription)")
                alertMessage = "캐릭터 중복 확인 중 오류가 발생했습니다."
                isShowingAlert = true
                return
            }

            if let document = document, document.exists {
                // 이미 존재함
                print("이미 등록된 캐릭터 이름입니다.")
                alertMessage = "이미 사용 중인 캐릭터 이름입니다. 다른 이름을 입력해주세요."
                isShowingAlert = true
            } else {
                // 저장
                docRef.setData([
                    "userId": user.uid,
                    "timestamp": FieldValue.serverTimestamp()
                ]) { error in
                    if let error = error {
                        print("Firestore 저장 실패: \(error.localizedDescription)")
                        alertMessage = "저장 중 오류가 발생했습니다."
                        isShowingAlert = true
                    } else {
                        print("캐릭터 이름 '\(characterName)' 저장 완료")
                        alertMessage = "설정이 저장되었습니다."
                        isShowingAlert = true
                    }
                }
            }
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
        
        isRefreshing = true
        
        Task {
            let result = await LostArkAPIService.shared.fetchCharacters(apiKey: apiKey, modelContext: modelContext)
            
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
                    alertMessage = "오류가 발생했습니다: \(error.localizedDescription)"
                }
                
                isShowingAlert = true
            }
        }
    }
    
    // 데이터 동기화
    private func syncData() {
        isDataSyncing = true
        
        Task {
            let success = await dataSyncManager.performManualSync()
            
            await MainActor.run {
                isDataSyncing = false
                
                if success {
                    alertMessage = "데이터가 성공적으로 동기화되었습니다."
                } else if let error = dataSyncManager.syncError {
                    alertMessage = "동기화 오류: \(error.localizedDescription)"
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
                    alertMessage = "로그아웃 중 오류가 발생했습니다."
                    isShowingAlert = true
                }
            }
        }
    }
    
    // 모든 데이터 초기화
    private func resetAllData() {
        // 모든 캐릭터 삭제
        do {
            try modelContext.delete(model: CharacterModel.self)
            alertMessage = "모든 데이터가 초기화되었습니다."
            isShowingAlert = true
            
            // 로그인 상태면 클라우드 데이터도 삭제
            if authManager.isLoggedIn {
                Task {
                    let repository = DataRepositoryFactory.getRepository(modelContext: modelContext)
                    try await repository.deleteAllCharacters()
                }
            }
        } catch {
            alertMessage = "데이터 초기화 중 오류가 발생했습니다."
            isShowingAlert = true
        }
    }
}

// SwiftData 모델 삭제 확장
extension ModelContext {
    func delete<T: PersistentModel>(model: T.Type) throws {
        let descriptor = FetchDescriptor<T>()
        let items = try fetch(descriptor)
        for item in items {
            delete(item)
        }
    }
}

// SettingsView에 업데이트 확인 및 앱스토어 실행 메소드 추가
extension SettingsView {
    // 업데이트 확인
    func checkForUpdates() {
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
