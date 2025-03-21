//
//  LostArkAPIService.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 3/20/25.
//

import Foundation
import SwiftData

// MARK: - API 응답 모델
struct CharacterResponse: Decodable {
    let ServerName: String
    let CharacterName: String
    let CharacterLevel: Int
    let CharacterClassName: String
    let ItemAvgLevel: String
    let ItemMaxLevel: String
    
    // 편의를 위한 계산 프로퍼티
    var serverName: String { ServerName }
    var characterName: String { CharacterName }
    var characterClassName: String { CharacterClassName }
    var itemLevel: Double {
        // 아이템 레벨은 "1,540.00", "1,302.50" 형태로 올 수 있으므로 변환 처리
        let cleanLevel = ItemMaxLevel.replacingOccurrences(of: ",", with: "")
        return Double(cleanLevel) ?? 0.0
    }
    var characterImage: String? { nil } // API에서 제공하지 않음
}

// MARK: - API 서비스
class LostArkAPIService {
    static let shared = LostArkAPIService()
    
    private init() {}
    
    private let baseURL = "https://developer-lostark.game.onstove.com"
    
    // 캐릭터 정보 가져오기
    func fetchCharacters(apiKey: String, modelContext: ModelContext) async {
        do {
            // 대표 캐릭터 이름 가져오기
            let characterName = UserDefaults.standard.string(forKey: "representativeCharacter") ?? ""
            
            if characterName.isEmpty {
                print("API Error: No representative character name")
                return
            }
            
            // 전체 API 요청 로깅
            print("API Request: Fetching siblings for \(characterName)")
            
            // siblings API 호출
            let encodedName = characterName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? characterName
            let url = URL(string: "\(baseURL)/characters/\(encodedName)/siblings")!
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            
            // API 가이드에 따른 헤더 설정
            request.addValue("application/json", forHTTPHeaderField: "accept")
            request.addValue("bearer \(apiKey)", forHTTPHeaderField: "authorization") // 소문자 'bearer'와 공백 사용
            
            // 모든 요청 헤더 로깅
            print("Request Headers: \(request.allHTTPHeaderFields ?? [:])")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("API Error: Invalid response")
                return
            }
            
            // 응답 헤더 확인 (요청 제한 정보)
            if let limitValue = httpResponse.value(forHTTPHeaderField: "X-RateLimit-Limit"),
               let remainingValue = httpResponse.value(forHTTPHeaderField: "X-RateLimit-Remaining") {
                print("API Rate Limit: \(limitValue), Remaining: \(remainingValue)")
            }
            
            // 응답 내용 로깅 (디버깅용)
            let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
            print("API Response Status: \(httpResponse.statusCode)")
            print("API Response: \(responseString)")
            
            if httpResponse.statusCode == 200 {
                // JSON 배열 형태의 응답 파싱
                let decoder = JSONDecoder()
                let charactersData = try decoder.decode([CharacterResponse].self, from: data)
                
                print("Successfully decoded \(charactersData.count) characters")
                
                // 메인 스레드에서 데이터 저장
                await MainActor.run {
                    for characterData in charactersData {
                        // 이미 존재하는 캐릭터인지 확인
                        let characterName = characterData.characterName
                        let fetchDescriptor = FetchDescriptor<CharacterModel>(
                            predicate: #Predicate<CharacterModel> { character in
                                character.name == characterName
                            }
                        )
                        let existingCharacters = try? modelContext.fetch(fetchDescriptor)
                        
                        if let existingCharacter = existingCharacters?.first {
                            // 기존 캐릭터 업데이트
                            existingCharacter.server = characterData.serverName
                            existingCharacter.characterClass = characterData.characterClassName
                            existingCharacter.level = characterData.itemLevel
                            existingCharacter.lastUpdated = Date()
                            // 레이드는 사용자가 직접 설정하도록 수정
                            // updateAvailableRaids 메서드를 더 이상 사용하지 않음
                            print("Updated character: \(characterData.characterName)")
                        } else {
                            // 새 캐릭터 추가
                            let newCharacter = CharacterModel(
                                name: characterData.characterName,
                                server: characterData.serverName,
                                characterClass: characterData.characterClassName,
                                level: characterData.itemLevel
                            )
                            modelContext.insert(newCharacter)
                            print("Added new character: \(characterData.characterName)")
                        }
                    }
                }
            } else {
                // 오류 응답 처리
                print("API Error (\(httpResponse.statusCode)): \(responseString)")
                
                // API 오류 코드에 따른 처리
                switch httpResponse.statusCode {
                case 401:
                    print("Authorization failed: Invalid API key or format")
                case 403:
                    print("Access forbidden: Insufficient permissions")
                case 429:
                    print("Rate limit exceeded: Too many requests")
                case 503:
                    print("Service unavailable: Maintenance in progress")
                default:
                    print("Unexpected error occurred")
                }
                
                // 에러가 발생했을 경우 단일 캐릭터라도 추가하기 위한 시도
                if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                    print("Trying to add single character manually...")
                    await addSingleCharacterManually(characterName: characterName, modelContext: modelContext)
                }
            }
        } catch {
            print("API Error: \(error.localizedDescription)")
        }
    }
    
    // 단일 캐릭터 정보 가져오기
    func fetchCharacter(name: String, apiKey: String) async throws -> CharacterResponse? {
        let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        let url = URL(string: "\(baseURL)/characters/\(encodedName)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "accept")
        request.addValue("bearer \(apiKey)", forHTTPHeaderField: "authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode(CharacterResponse.self, from: data)
    }
    
    // API 호출이 실패했을 때 수동으로 단일 캐릭터 추가 (임시 해결 방법)
    @MainActor
    private func addSingleCharacterManually(characterName: String, modelContext: ModelContext) async {
        // 대표 캐릭터 한 개라도 추가하기 위한 임시 방법
        let fetchDescriptor = FetchDescriptor<CharacterModel>(
            predicate: #Predicate<CharacterModel> { character in
                character.name == characterName
            }
        )
        
        if let existingCharacters = try? modelContext.fetch(fetchDescriptor), existingCharacters.isEmpty {
            // 캐릭터가 아직 없으면 예시 데이터로라도 추가
            let newCharacter = CharacterModel(
                name: characterName,
                server: "대표 서버",  // 실제 서버 정보 없음
                characterClass: "대표 직업", // 실제 클래스 정보 없음
                level: 1500.0  // 예시 레벨
            )
            modelContext.insert(newCharacter)
            print("Added representative character manually: \(characterName)")
        }
    }
}
