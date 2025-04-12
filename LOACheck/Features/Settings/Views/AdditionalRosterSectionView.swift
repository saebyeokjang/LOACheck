//
//  AdditionalRosterSectionView.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 4/11/25.
//

import SwiftUI
import SwiftData

struct AdditionalRosterSectionView: View {
    var apiKey: String
    var authManager: AuthManager
    var networkMonitor: NetworkMonitorService
    var modelContext: ModelContext
    var dataSyncManager: DataSyncManager
    var errorService: ErrorHandlingService
    @Binding var alertMessage: String
    @Binding var isShowingAlert: Bool
    @State private var otherCharacterName: String = ""
    @State private var isFetchingOtherRoster: Bool = false
    
    var body: some View {
        Section(header: Text("원정대 추가"), footer: Text("캐릭터의 전체 원정대를 추가합니다.")) {
            TextField("캐릭터 이름 입력", text: $otherCharacterName)
                .autocorrectionDisabled()
                .submitLabel(.done)
            
            Button(action: fetchAdditionalRoster) {
                HStack {
                    Text("원정대 추가하기")
                    if isFetchingOtherRoster {
                        Spacer()
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
            .disabled(apiKey.isEmpty || otherCharacterName.isEmpty || isFetchingOtherRoster || !networkMonitor.isConnected)
        }
    }
    
    // 추가 원정대 불러오기
    private func fetchAdditionalRoster() {
        guard !apiKey.isEmpty else {
            alertMessage = "API 키를 먼저 입력해주세요."
            isShowingAlert = true
            return
        }
        
        guard !otherCharacterName.isEmpty else {
            alertMessage = "캐릭터 이름을 입력해주세요."
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
            // 1. 먼저 캐릭터 존재 여부 확인
            let validationResult = await LostArkAPIService.shared.validateCharacter(
                name: otherCharacterName,
                apiKey: apiKey
            )
            
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
                
                // 2. 캐릭터 원정대 정보 불러오기 (기존 데이터 유지)
                let result = await LostArkAPIService.shared.fetchAdditionalRoster(
                    characterName: otherCharacterName,
                    apiKey: apiKey,
                    modelContext: modelContext
                )
                
                await MainActor.run {
                    isFetchingOtherRoster = false
                    
                    switch result {
                    case .success(let count):
                        alertMessage = "\(otherCharacterName) 원정대 정보를 성공적으로 불러왔습니다. (\(count)개)"
                        otherCharacterName = "" // 입력 필드 초기화
                        
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
        }
    }
}
