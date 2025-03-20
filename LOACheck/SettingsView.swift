//
//  SettingsView.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 3/20/25.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @AppStorage("apiKey") private var apiKey: String = "eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsIng1dCI6IktYMk40TkRDSTJ5NTA5NWpjTWk5TllqY2lyZyIsImtpZCI6IktYMk40TkRDSTJ5NTA5NWpjTWk5TllqY2lyZyJ9.eyJpc3MiOiJodHRwczovL2x1ZHkuZ2FtZS5vbnN0b3ZlLmNvbSIsImF1ZCI6Imh0dHBzOi8vbHVkeS5nYW1lLm9uc3RvdmUuY29tL3Jlc291cmNlcyIsImNsaWVudF9pZCI6IjEwMDAwMDAwMDAxNTQxNDQifQ.A9Bjw7h72Wz17Mjj47rs2bTsV11WBwFLC734G5XAn5kBDDyqQAOINwsU93SrSOfErCzy3XaU8F0rorpAPWIXj18YE5etud5veJZ4-6-KEgfQiDpDOM98JJjHD0DKxD6im9op1KoPSGgNqXtrDEtxXgp2ll0yM-PXC52ZWsnXGlu3T1VyznrR-fgKI79btydeN36c8df67g3OzvbRDOSi6PuhID1OtEql5RSqCFxzj8VZt2HVy50s6YXdClyQatCb4yGfTox5CC_TQxnCG8Z5NM-VVj9_1VGl3SWd4JZC6TwG4xRVXiqu706dKF-fLhAHfUEMxVJlh4Vc4o9KtEifcw"
    @State private var tempApiKey: String = ""
    
    @AppStorage("representativeCharacter") private var representativeCharacter: String = ""
    @State private var tempRepChar: String = ""
    
    @State private var isShowingAlert = false
    @State private var alertMessage = ""
    @State private var isRefreshing = false
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("로스트아크 API 설정"), footer: Text("로스트아크 개발자 포털(https://developer-lostark.game.onstove.com)에서 API 키를 발급받을 수 있습니다.")) {
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
                    Button(action: resetAllData) {
                        Text("모든 데이터 초기화")
                            .foregroundColor(.red)
                    }
                }
                
                Section(header: Text("만든 사람")) {
                    Link("개발자에게 피드백 보내기", destination: URL(string: "mailto:your-email@example.com")!)
                }
            }
            .navigationTitle("설정")
            .alert(isPresented: $isShowingAlert) {
                Alert(
                    title: Text("알림"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("확인"))
                )
            }
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
            await LostArkAPIService.shared.fetchCharacters(apiKey: apiKey, modelContext: modelContext)
            
            await MainActor.run {
                isRefreshing = false
                alertMessage = "캐릭터 정보를 불러왔습니다."
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
