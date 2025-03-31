//
//  SettingsView.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 3/20/25.
//

import SwiftUI
import SwiftData

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
    
    var body: some View {
        NavigationStack {
            Form {
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
    }
    
    // 설정 저장 (API 키와 대표 캐릭터)
    private func saveSettings() {
        // 키보드 숨기기
        isApiKeyFocused = false
        isCharNameFocused = false
        
        apiKey = tempApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        representativeCharacter = tempRepChar.trimmingCharacters(in: .whitespacesAndNewlines)
        alertMessage = "설정이 저장되었습니다."
        isShowingAlert = true
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
                case .failure(let error):
                    alertMessage = "오류가 발생했습니다: \(error.localizedDescription)"
                }
                
                isShowingAlert = true
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
