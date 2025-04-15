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
    
    static func == (lhs: APIError, rhs: APIError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidResponse, .invalidResponse),
            (.unauthorized, .unauthorized),
            (.forbidden, .forbidden),
            (.rateLimit, .rateLimit),
            (.serviceUnavailable, .serviceUnavailable):
            return true
        case (.unknown(let lhsCode), .unknown(let rhsCode)):
            return lhsCode == rhsCode
        case (.networkError(let lhsError), .networkError(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
    
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
    @MainActor
    func fetchCharacters(apiKey: String, modelContext: ModelContext, clearExisting: Bool = false) async -> Result<Int, APIError> {
        do {
            let characterName = UserDefaults.standard.string(forKey: "representativeCharacter") ?? ""
            
            if characterName.isEmpty {
                Logger.error("No representative character name")
                return .failure(.invalidResponse)
            }
            
            Logger.debug("API Request: Fetching siblings for \(characterName)")
            
            // 기존 데이터를 초기화해야 하는 경우
            if clearExisting {
                try safeClearExistingData(modelContext: modelContext)
            }
            
            // API 호출 및 데이터 처리
            let encodedName = characterName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? characterName
            let url = URL(string: "\(baseURL)/characters/\(encodedName)/siblings")!
            
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
                    if let singleCharacter = try? await fetchCharacter(name: characterName, apiKey: apiKey) {
                        allCharactersData.append(singleCharacter)
                    }
                }
                
                // 안전하게 캐릭터 모델 업데이트
                await updateCharacterModels(charactersData: allCharactersData, modelContext: modelContext, clearExisting: clearExisting)
                
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
    
    // 다른 원정대의 캐릭터 정보를 기존 데이터에 추가하는 함수
    @MainActor
    func fetchAdditionalRoster(characterName: String, apiKey: String, modelContext: ModelContext) async -> Result<Int, APIError> {
        do {
            Logger.debug("API Request: Fetching additional roster for \(characterName)")
            
            // API 호출 및 데이터 처리
            let encodedName = characterName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? characterName
            let url = URL(string: "\(baseURL)/characters/\(encodedName)/siblings")!
            
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
                
                var allCharactersData = charactersData
                
                // 검색한 캐릭터가 목록에 없으면 따로 추가
                var hasSearchedCharacter = false
                for character in charactersData {
                    if character.characterName == characterName {
                        hasSearchedCharacter = true
                        break
                    }
                }
                
                if !hasSearchedCharacter {
                    Logger.debug("검색한 캐릭터가 응답에 없음, 직접 요청 시도: \(characterName)")
                    if let singleCharacter = try? await fetchCharacter(name: characterName, apiKey: apiKey) {
                        allCharactersData.append(singleCharacter)
                    }
                }
                
                // 기존 데이터를 유지하면서 추가 캐릭터만 업데이트
                await updateCharacterModels(charactersData: allCharactersData, modelContext: modelContext, clearExisting: false)
                
                return .success(allCharactersData.count)
                
            case 401:
                Logger.error("Authorization failed: Invalid API key or format")
                return .failure(.unauthorized)
                
            // 다른 상태 코드 처리는 위와 동일
            default:
                Logger.error("Unexpected error occurred with status code: \(httpResponse.statusCode)")
                return .failure(.unknown(httpResponse.statusCode))
            }
        } catch {
            Logger.error("API Error", error: error)
            return .failure(.networkError(error))
        }
    }
    
    // 기존 데이터를 안전하게 초기화하는 함수
    @MainActor
    private func safeClearExistingData(modelContext: ModelContext) throws {
        // 안전하게 데이터 삭제 (순서 중요)
        let taskDescriptor = FetchDescriptor<DailyTask>()
        let tasks = try modelContext.fetch(taskDescriptor)
        for task in tasks {
            modelContext.delete(task)
        }
        try modelContext.save()
        
        let gateDescriptor = FetchDescriptor<RaidGate>()
        let gates = try modelContext.fetch(gateDescriptor)
        for gate in gates {
            modelContext.delete(gate)
        }
        try modelContext.save()
        
        let characterDescriptor = FetchDescriptor<CharacterModel>()
        let characters = try modelContext.fetch(characterDescriptor)
        for character in characters {
            modelContext.delete(character)
        }
        try modelContext.save()
    }
    
    // 캐릭터 데이터 업데이트를 위한 별도 메소드
    @MainActor
    private func updateCharacterModels(charactersData: [CharacterResponse], modelContext: ModelContext, clearExisting: Bool) async {
        // 추가하려는 캐릭터 이름 목록
        let newCharacterNames = charactersData.map { $0.characterName }
        
        // 캐릭터 데이터 처리
        for characterData in charactersData {
            let characterName = characterData.characterName
            
            // 이미 존재하는 캐릭터인지 확인
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
                
                Logger.debug("Updated character: \(characterName)")
            } else {
                // 새 캐릭터 추가
                let newCharacter = CharacterModel(
                    name: characterData.characterName,
                    server: characterData.serverName,
                    characterClass: characterData.characterClassName,
                    level: characterData.itemLevel
                )
                modelContext.insert(newCharacter)
                
                Logger.debug("Added new character: \(characterName)")
            }
        }
        
        try? modelContext.save()
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
    
    // 캐릭터 존재 여부 확인 메서드
    func validateCharacter(name: String, apiKey: String) async -> Result<Bool, APIError> {
        do {
            let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
            let url = URL(string: "\(baseURL)/characters/\(encodedName)")!
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.addValue("application/json", forHTTPHeaderField: "accept")
            request.addValue("bearer \(apiKey)", forHTTPHeaderField: "authorization")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(.invalidResponse)
            }
            
            switch httpResponse.statusCode {
            case 200:
                // 성공적으로 캐릭터 정보를 받으면 존재하는 캐릭터
                return .success(true)
            case 404:
                // 404 오류는 캐릭터를 찾을 수 없음을 의미
                return .success(false)
            case 401:
                return .failure(.unauthorized)
            case 403:
                return .failure(.forbidden)
            case 429:
                return .failure(.rateLimit)
            case 503:
                return .failure(.serviceUnavailable)
            default:
                return .failure(.unknown(httpResponse.statusCode))
            }
        } catch {
            return .failure(.networkError(error))
        }
    }
}

extension APIError {
    // 사용자에게 보여줄 표준화된 메시지
    var userFriendlyMessage: String {
        switch self {
        case .serviceUnavailable:
            return "로스트아크 API 서비스가 현재 점검 중입니다."
        case .rateLimit:
            return "API 호출 한도를 초과했습니다.\n잠시 후 다시 시도해 주세요."
        case .unauthorized:
            return "API 키가 유효하지 않습니다.\n설정에서 API 키를 확인해 주세요."
        case .forbidden:
            return "API 접근 권한이 없습니다.\n설정에서 API 키를 확인해 주세요."
        case .invalidResponse, .unknown(_), .networkError(_):
            return "네트워크 오류가 발생했습니다.\n인터넷 연결을 확인하고 다시 시도해 주세요."
        }
    }
}
