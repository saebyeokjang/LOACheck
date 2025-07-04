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
            if !authManager.representativeCharacter.isEmpty {
                // 기존 원정대 갱신 버튼
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
            } else {
                // 대표 캐릭터 미설정 안내 (간단 버전)
                Text("대표 캐릭터를 설정해주세요")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                    .padding(.vertical, 4)
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
                        switch result {
                        case .success(let count):
                            // 3. 모든 캐릭터 전투력 갱신 시작
                            Task {
                                let combatPowerResult = await LostArkAPIService.shared.updateAllCharactersCombatPower(
                                    apiKey: apiKey,
                                    modelContext: modelContext
                                )
                                
                                await MainActor.run {
                                    isRefreshing = false
                                    
                                    // 결과 메시지 생성
                                    var message = "원정대 갱신 완료! (\(count)개)\n"
                                    
                                    if combatPowerResult.successCount > 0 {
                                        message += "전투력 갱신 성공: \(combatPowerResult.successCount)개\n"
                                    }
                                    
                                    if combatPowerResult.failureCount > 0 {
                                        message += "전투력 갱신 실패: \(combatPowerResult.failureCount)개"
                                    }
                                    
                                    alertMessage = message
                                    
                                    // 로그인 상태면 데이터 동기화 필요 표시
                                    if authManager.isLoggedIn {
                                        dataSyncManager.markLocalChanges()
                                    }
                                    
                                    isShowingAlert = true
                                }
                            }
                            
                        case .failure(let error):
                            isRefreshing = false
                            handleRefreshError(error)
                        }
                    }
                    
                case .failure(let error):
                    await MainActor.run {
                        isRefreshing = false
                        handleRefreshError(error)
                    }
                }
            } catch {
                await MainActor.run {
                    isRefreshing = false
                    alertMessage = "네트워크 오류가 발생했습니다."
                    isShowingAlert = true
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
            // 개선된 헤더 형식 사용
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.addValue("LOACheck/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(.invalidResponse)
            }
            
            // 응답 디버깅
            if let responseString = String(data: data, encoding: .utf8) {
                Logger.debug("API 응답: \(responseString.prefix(500))...")
            }
            
            // API 응답 처리
            switch httpResponse.statusCode {
            case 200:
                let decoder = JSONDecoder()
                
                do {
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
                    
                    // 대표 캐릭터가 없으면 따로 추가 시도
                    if !hasRepresentativeCharacter {
                        Logger.debug("대표 캐릭터가 응답에 없음, 직접 요청 시도: \(characterName)")
                        
                        // 단일 캐릭터 API 호출
                        let singleCharacterUrl = URL(string: "\(LostArkAPIService.shared.baseURL)/characters/\(encodedName)")!
                        var singleRequest = URLRequest(url: singleCharacterUrl)
                        singleRequest.httpMethod = "GET"
                        singleRequest.addValue("application/json", forHTTPHeaderField: "Accept")
                        singleRequest.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                        singleRequest.addValue("LOACheck/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
                        
                        if let (singleData, singleResponse) = try? await URLSession.shared.data(for: singleRequest),
                           let singleHttpResponse = singleResponse as? HTTPURLResponse,
                           singleHttpResponse.statusCode == 200,
                           let singleCharacter = try? decoder.decode(CharacterResponse.self, from: singleData) {
                            allCharactersData.append(singleCharacter)
                            Logger.debug("단일 캐릭터 추가 성공: \(characterName)")
                        } else {
                            Logger.warning("단일 캐릭터 요청 실패: \(characterName)")
                        }
                    }
                    
                    // 기존 데이터 유지하면서 캐릭터 정보만 업데이트
                    await updateExistingCharacters(charactersData: allCharactersData)
                    
                    return .success(allCharactersData.count)
                    
                } catch let decodingError {
                    Logger.error("JSON 디코딩 실패", error: decodingError)
                    
                    // 상세한 디코딩 오류 분석
                    if let error = decodingError as? DecodingError {
                        switch error {
                        case .keyNotFound(let key, let context):
                            Logger.error("누락된 키: \(key.stringValue), 경로: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                        case .typeMismatch(let type, let context):
                            Logger.error("타입 불일치: 예상 \(type), 경로: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                        case .valueNotFound(let type, let context):
                            Logger.error("값 없음: \(type), 경로: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                        case .dataCorrupted(let context):
                            Logger.error("데이터 손상: \(context.debugDescription)")
                        @unknown default:
                            Logger.error("알 수 없는 디코딩 오류: \(error)")
                        }
                    }
                    
                    return .failure(.networkError(decodingError))
                }
                
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
                // 기존 캐릭터 업데이트 (일일 숙제 및 레이드 설정 유지)
                existingCharacter.server = characterData.serverName
                existingCharacter.characterClass = characterData.characterClassName
                existingCharacter.level = characterData.itemLevel
                existingCharacter.lastUpdated = Date()
                
                updatedCount += 1
                Logger.debug("기존 캐릭터 업데이트: \(characterName)")
            } else {
                // 새 캐릭터 추가
                let newCharacter = CharacterModel(
                    name: characterName,
                    server: characterData.serverName,
                    characterClass: characterData.characterClassName,
                    level: characterData.itemLevel
                )
                modelContext.insert(newCharacter)
                
                newCount += 1
                Logger.debug("새 캐릭터 추가: \(characterName)")
            }
        }
        
        // 변경사항 저장
        do {
            try modelContext.save()
            Logger.debug("캐릭터 데이터 업데이트 완료 - 업데이트: \(updatedCount)개, 신규: \(newCount)개")
        } catch {
            Logger.error("캐릭터 데이터 저장 오류", error: error)
        }
    }
    
    private func handleRefreshError(_ error: APIError) {
        switch error {
        case .serviceUnavailable:
            alertMessage = "로스트아크 API 서비스가 현재 점검 중입니다."
        case .rateLimit:
            alertMessage = "API 호출 한도를 초과했습니다. 잠시 후 다시 시도해주세요."
        case .unauthorized:
            alertMessage = "API 키가 유효하지 않습니다."
        case .forbidden:
            alertMessage = "API 접근 권한이 없습니다."
        default:
            alertMessage = "원정대 갱신 중 오류가 발생했습니다."
        }
        isShowingAlert = true
    }
}
