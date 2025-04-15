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
                        Text("원정대 갱신하기")
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
    
    // API 키 테스트 및 캐릭터 정보만 업데이트 (일일 숙제 및 레이드 설정 유지)
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
                    
                    // 2. 캐릭터 정보 불러오되 기존 데이터 유지
                    let result = await updateCharactersInfoOnly(apiKey: apiKey)
                    
                    await MainActor.run {
                        isRefreshing = false
                        
                        switch result {
                        case .success(let count):
                            alertMessage = "캐릭터 정보를 성공적으로 업데이트했습니다. (\(count)개)"
                            
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
    
    // 캐릭터 정보만 업데이트하는 메서드 (일일 숙제 및 레이드 설정 유지)
    private func updateCharactersInfoOnly(apiKey: String) async -> Result<Int, APIError> {
        do {
            let characterName = authManager.representativeCharacter
            Logger.debug("API Request: Fetching siblings for \(characterName)")
            
            // API 호출 및 데이터 처리
            let encodedName = characterName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? characterName
            let url = URL(string: "\(LostArkAPIService.shared.baseURL)/characters/\(encodedName)/siblings")!
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.addValue("application/json", forHTTPHeaderField: "accept")
            request.addValue("bearer \(apiKey)", forHTTPHeaderField: "authorization")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(.invalidResponse)
            }
            
            // API 응답 처리
            switch httpResponse.statusCode {
            case 200:
                let decoder = JSONDecoder()
                let charactersData = try decoder.decode([CharacterResponse].self, from: data)
                
                // 대표 캐릭터가 있는지 확인
                var hasRepresentativeCharacter = false
                for character in charactersData {
                    if character.characterName == characterName {
                        hasRepresentativeCharacter = true
                        break
                    }
                }
                
                var allCharactersData = charactersData
                
                // 대표 캐릭터가 없으면 따로 추가
                if !hasRepresentativeCharacter {
                    Logger.debug("대표 캐릭터가 응답에 없음, 직접 요청 시도: \(characterName)")
                    if let singleCharacter = try? await LostArkAPIService.shared.fetchCharacter(name: characterName, apiKey: apiKey) {
                        allCharactersData.append(singleCharacter)
                    }
                }
                
                // 기존 데이터 유지하면서 캐릭터 정보만 업데이트
                await updateExistingCharacters(charactersData: allCharactersData)
                
                return .success(allCharactersData.count)
                
            case 401:
                Logger.error("Authorization failed: Invalid API key or format")
                return .failure(.unauthorized)
                
            case 403:
                Logger.error("Access forbidden: Insufficient permissions")
                return .failure(.forbidden)
                
            case 429:
                Logger.error("Rate limit exceeded: Too many requests")
                return .failure(.rateLimit)
                
            case 503:
                Logger.error("Service unavailable: Maintenance in progress")
                return .failure(.serviceUnavailable)
                
            default:
                Logger.error("Unexpected error occurred with status code: \(httpResponse.statusCode)")
                return .failure(.unknown(httpResponse.statusCode))
            }
        } catch {
            Logger.error("API Error", error: error)
            return .failure(.networkError(error))
        }
    }
    
    // 기존 캐릭터 데이터 유지하면서 서버, 클래스, 레벨 정보만 업데이트
    @MainActor
    private func updateExistingCharacters(charactersData: [CharacterResponse]) async {
        var updatedCount = 0
        var newCount = 0
        
        for characterData in charactersData {
            let characterName = characterData.characterName
            
            // 이미 존재하는 캐릭터인지 확인
            let fetchDescriptor = FetchDescriptor<CharacterModel>(
                predicate: #Predicate<CharacterModel> { character in
                    character.name == characterName
                }
            )
            
            if let existingCharacters = try? modelContext.fetch(fetchDescriptor),
               let existingCharacter = existingCharacters.first {
                // 기존 캐릭터의 서버, 클래스, 레벨 정보만 업데이트
                let hasChanged = existingCharacter.server != characterData.serverName ||
                                existingCharacter.characterClass != characterData.characterClassName ||
                                abs(existingCharacter.level - characterData.itemLevel) > 0.01
                
                if hasChanged {
                    existingCharacter.server = characterData.serverName
                    existingCharacter.characterClass = characterData.characterClassName
                    existingCharacter.level = characterData.itemLevel
                    existingCharacter.lastUpdated = Date()
                    updatedCount += 1
                }
                
                Logger.debug("Updated character info: \(characterData.characterName)")
            } else {
                // 새 캐릭터 추가
                let newCharacter = CharacterModel(
                    name: characterData.characterName,
                    server: characterData.serverName,
                    characterClass: characterData.characterClassName,
                    level: characterData.itemLevel
                )
                modelContext.insert(newCharacter)
                newCount += 1
                
                Logger.debug("Added new character: \(characterData.characterName)")
            }
        }
        
        Logger.info("캐릭터 정보 업데이트 완료: \(updatedCount)개 업데이트, \(newCount)개 추가")
        
        try? modelContext.save()
    }
}
