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

// MARK: - API 에러 타입
enum APIError: Error, LocalizedError {
    case invalidResponse
    case unauthorized
    case forbidden
    case rateLimit
    case serviceUnavailable
    case unknown(Int)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "유효하지 않은 응답입니다."
        case .unauthorized:
            return "API 키가 유효하지 않거나 형식이 잘못되었습니다."
        case .forbidden:
            return "API 접근 권한이 없습니다."
        case .rateLimit:
            return "API 호출 한도를 초과했습니다. 잠시 후 다시 시도해주세요."
        case .serviceUnavailable:
            return "로스트아크 API 서비스가 현재 점검 중입니다."
        case .unknown(let code):
            return "예상치 못한 오류가 발생했습니다 (코드: \(code))"
        case .networkError(let error):
            return "네트워크 오류: \(error.localizedDescription)"
        }
    }
}

// MARK: - API 서비스
class LostArkAPIService {
    static let shared = LostArkAPIService()
    
    private init() {}
    
    private let baseURL = "https://developer-lostark.game.onstove.com"
    
    // 캐릭터 정보 가져오기
    func fetchCharacters(apiKey: String, modelContext: ModelContext) async -> Result<Int, APIError> {
        do {
            let characterName = UserDefaults.standard.string(forKey: "representativeCharacter") ?? ""
            
            if characterName.isEmpty {
                Logger.error("No representative character name")
                return .failure(.invalidResponse)
            }
            
            Logger.debug("API Request: Fetching siblings for \(characterName)")
            
            let encodedName = characterName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? characterName
            let url = URL(string: "\(baseURL)/characters/\(encodedName)/siblings")!
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.addValue("application/json", forHTTPHeaderField: "accept")
            request.addValue("bearer \(apiKey)", forHTTPHeaderField: "authorization")
            
            Logger.debug("Request Headers: \(request.allHTTPHeaderFields ?? [:])")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(.invalidResponse)
            }
            
            // 응답 헤더 확인 (요청 제한 정보)
            if let limitValue = httpResponse.value(forHTTPHeaderField: "X-RateLimit-Limit"),
               let remainingValue = httpResponse.value(forHTTPHeaderField: "X-RateLimit-Remaining") {
                Logger.debug("API Rate Limit: \(limitValue), Remaining: \(remainingValue)")
            }
            
            // 디버그 모드에서만 응답 로깅
            #if DEBUG
            let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
            Logger.debug("API Response Status: \(httpResponse.statusCode)")
            Logger.debug("API Response: \(responseString)")
            #endif
            
            switch httpResponse.statusCode {
            case 200:
                let decoder = JSONDecoder()
                let charactersData = try decoder.decode([CharacterResponse].self, from: data)
                
                Logger.debug("Successfully decoded \(charactersData.count) characters")
                
                await MainActor.run {
                    self.updateCharacterModels(charactersData: charactersData, modelContext: modelContext)
                }
                
                return .success(charactersData.count)
                
            case 401:
                Logger.error("Authorization failed: Invalid API key or format")
                
                // 오류 시 단일 캐릭터 추가 시도
                await addSingleCharacterManually(characterName: characterName, modelContext: modelContext)
                return .failure(.unauthorized)
                
            case 403:
                Logger.error("Access forbidden: Insufficient permissions")
                
                await addSingleCharacterManually(characterName: characterName, modelContext: modelContext)
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
    
    // 캐릭터 데이터 업데이트를 위한 별도 메소드
    @MainActor
    private func updateCharacterModels(charactersData: [CharacterResponse], modelContext: ModelContext) {
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
                
                Logger.debug("Updated character: \(characterData.characterName)")
            } else {
                // 새 캐릭터 추가
                let newCharacter = CharacterModel(
                    name: characterData.characterName,
                    server: characterData.serverName,
                    characterClass: characterData.characterClassName,
                    level: characterData.itemLevel
                )
                modelContext.insert(newCharacter)
                
                Logger.debug("Added new character: \(characterData.characterName)")
            }
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
            Logger.debug("Added representative character manually: \(characterName)")
        }
    }
}
