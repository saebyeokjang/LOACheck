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
    
    @State private var isShowingAlert = false
    @State private var alertMessage = ""
    @State private var isRefreshing = false
    @State private var isShowingResetConfirmation = false // 데이터 초기화 확인용
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("로스트아크 API 설정"), footer: Text("로스트아크 개발자 포털 (https://developer-lostark.game.onstove.com) 에서 API 키를 발급받을 수 있습니다.")) {
                    SecureField("API 키 입력", text: $tempApiKey)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onAppear {
                            tempApiKey = apiKey
                        }
                    
                    TextField("대표 캐릭터 이름", text: $tempRepChar)
                        .autocorrectionDisabled()
                        .onAppear {
                            tempRepChar = representativeCharacter
                        }
                    
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
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
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
                    Link("개발자에게 피드백 보내기", destination: URL(string: "dev.saebyeok@gmail.com")!)
                }
            }
            .navigationTitle("설정")
            // 일반 알림
            .alert(isPresented: $isShowingAlert) {
                Alert(
                    title: Text("알림"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("확인"))
                )
            }
        }
        // 데이터 초기화 확인 알림
        .alert(isPresented: $isShowingResetConfirmation) {
            Alert(
                title: Text("데이터 초기화 확인"),
                message: Text("모든 캐릭터 데이터가 영구적으로 삭제됩니다.\n이 작업은 되돌릴 수 없습니다.\n계속하시겠습니까?"),
                primaryButton: .destructive(Text("초기화")) {
                    resetAllData()
                },
                secondaryButton: .cancel(Text("취소"))
            )
        }
    }
    
    // 설정 저장 (API 키와 대표 캐릭터)
    private func saveSettings() {
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
