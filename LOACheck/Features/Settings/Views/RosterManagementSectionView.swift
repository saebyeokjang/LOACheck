//
//  RosterManagementSectionView.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 4/11/25.
//

import SwiftUI
import SwiftData

struct RosterManagementSectionView: View {
    var apiKey: String
    var authManager: AuthManager
    var networkMonitor: NetworkMonitorService
    var modelContext: ModelContext
    var dataSyncManager: DataSyncManager
    var errorService: ErrorHandlingService
    @Binding var alertMessage: String
    @Binding var isShowingAlert: Bool
    @State private var isRefreshing = false
    
    var body: some View {
        Section(header: Text("원정대 관리")) {
            // 기본 원정대 불러오기
            if !authManager.representativeCharacter.isEmpty {
                Button(action: testAndFetchCharacters) {
                    HStack {
                        Text("기본 원정대 불러오기")
                        if isRefreshing {
                            Spacer()
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                }
                .disabled(apiKey.isEmpty || isRefreshing || !networkMonitor.isConnected)
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
        
        guard !authManager.representativeCharacter.isEmpty else {
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
                let validationResult = await LostArkAPIService.shared.validateCharacter(name: authManager.representativeCharacter, apiKey: apiKey)
                
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
                        clearExisting: true
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
}

#Preview {
    RosterManagementSectionView(
        apiKey: "",
        authManager: AuthManager.shared,
        networkMonitor: NetworkMonitorService.shared,
        modelContext: ModelContext(try! ModelContainer(for: CharacterModel.self)),
        dataSyncManager: DataSyncManager.shared,
        errorService: ErrorHandlingService(),
        alertMessage: .constant(""),
        isShowingAlert: .constant(false)
    )
}
