//
//  LostArkAPIService.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 3/20/25.
//

import Foundation
import SwiftData
import FirebaseAnalytics

struct CharacterResponse: Decodable {
    let ServerName: String?
    let CharacterName: String?
    let CharacterLevel: Int?
    let CharacterClassName: String?
    let ItemAvgLevel: String?
    let ItemMaxLevel: String?
    let CombatPower: String?
    
    // 편의를 위한 계산 프로퍼티 (안전한 기본값 제공)
    var serverName: String { ServerName ?? "Unknown Server" }
    var characterName: String { CharacterName ?? "Unknown Character" }
    var characterClassName: String { CharacterClassName ?? "Unknown Class" }
    var itemLevel: Double {
        // ItemMaxLevel이 없으면 ItemAvgLevel을 시도
        let levelString = ItemMaxLevel ?? ItemAvgLevel ?? "0"
        Logger.debug("원본 아이템 레벨 데이터: \(levelString)")
        
        let cleanLevel = levelString.replacingOccurrences(of: ",", with: "")
        let parsedLevel = Double(cleanLevel) ?? 0.0
        
        Logger.debug("변환된 아이템 레벨: \(parsedLevel)")
        return parsedLevel
    }
    var combatPower: Double {
        let powerString = CombatPower ?? "0"
        let cleanPower = powerString.replacingOccurrences(of: ",", with: "")
        return Double(cleanPower) ?? 0.0
    }
    var characterImage: String? { nil } // API에서 제공하지 않음
    
    // 커스텀 디코딩 초기화 (필수 필드만 체크)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // 모든 필드를 옵셔널로 처리
        ServerName = try container.decodeIfPresent(String.self, forKey: .ServerName)
        CharacterName = try container.decodeIfPresent(String.self, forKey: .CharacterName)
        CharacterLevel = try container.decodeIfPresent(Int.self, forKey: .CharacterLevel)
        CharacterClassName = try container.decodeIfPresent(String.self, forKey: .CharacterClassName)
        ItemAvgLevel = try container.decodeIfPresent(String.self, forKey: .ItemAvgLevel)
        ItemMaxLevel = try container.decodeIfPresent(String.self, forKey: .ItemMaxLevel)
        CombatPower = try container.decodeIfPresent(String.self, forKey: .CombatPower)
        
        // 디버깅용 로그
        Logger.debug("디코딩된 캐릭터: \(CharacterName ?? "nil")")
        Logger.debug("사용 가능한 키들: \(container.allKeys.map { $0.stringValue })")
    }
    
    private enum CodingKeys: String, CodingKey {
        case ServerName, CharacterName, CharacterLevel, CharacterClassName, ItemAvgLevel, ItemMaxLevel, CombatPower
    }
}

// MARK: - 유연한 캐릭터 프로필 응답 모델
struct CharacterProfileResponse: Decodable {
    let serverName: String?
    let characterName: String?
    let characterClassName: String?
    let itemAvgLevel: String?
    let itemMaxLevel: String?
    let combatPower: String?
    
    // 안전한 접근을 위한 계산 프로퍼티
    var safeServerName: String { serverName ?? "Unknown Server" }
    var safeCharacterName: String { characterName ?? "Unknown Character" }
    var safeCharacterClassName: String { characterClassName ?? "Unknown Class" }
    var safeItemMaxLevel: String { itemMaxLevel ?? itemAvgLevel ?? "0" }
    var safeCombatPower: String { combatPower ?? "0" }
    
    enum CodingKeys: String, CodingKey {
        case serverName = "ServerName"
        case characterName = "CharacterName"
        case characterClassName = "CharacterClassName"
        case itemAvgLevel = "ItemAvgLevel"
        case itemMaxLevel = "ItemMaxLevel"
        case combatPower = "CombatPower"
    }
    
    // 커스텀 디코딩으로 필드 누락 대응
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        serverName = try container.decodeIfPresent(String.self, forKey: .serverName)
        characterName = try container.decodeIfPresent(String.self, forKey: .characterName)
        characterClassName = try container.decodeIfPresent(String.self, forKey: .characterClassName)
        itemAvgLevel = try container.decodeIfPresent(String.self, forKey: .itemAvgLevel)
        itemMaxLevel = try container.decodeIfPresent(String.self, forKey: .itemMaxLevel)
        combatPower = try container.decodeIfPresent(String.self, forKey: .combatPower)
        
        // 사용 가능한 모든 키 로깅 (API 구조 변경 감지용)
        Logger.debug("프로필 API 응답 키들: \(container.allKeys.map { $0.stringValue })")
    }
}

// MARK: - API 에러 타입
enum APIError: Error, LocalizedError {
    case invalidResponse
    case unauthorized
    case forbidden
    case rateLimit
    case serviceUnavailable
    case documentNotFound
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
        case .documentNotFound:
            return "요청한 캐릭터 정보를 찾을 수 없습니다."
        case .unknown(let code):
            return "예상치 못한 오류가 발생했습니다 (코드: \(code))"
        case .networkError(let error):
            return "네트워크 오류: \(error.localizedDescription)"
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
        case .documentNotFound:
            return "요청한 캐릭터 정보를 찾을 수 없습니다."
        case .forbidden:
            return "API 접근 권한이 없습니다.\n설정에서 API 키를 확인해 주세요."
        case .invalidResponse, .unknown(_), .networkError(_):
            return "네트워크 오류가 발생했습니다.\n인터넷 연결을 확인하고 다시 시도해 주세요."
        }
    }
}

// MARK: - API 서비스
class LostArkAPIService {
    static let shared = LostArkAPIService()
    private var hasLoggedCharactersThisSession = false
    
    private init() {}
    
    let baseURL = "https://developer-lostark.game.onstove.com"
    
    // MARK: - 메인 캐릭터 정보 가져오기 (개선된 버전)
    @MainActor
    func fetchCharacters(apiKey: String, modelContext: ModelContext, clearExisting: Bool = false) async -> Result<Int, APIError> {
        do {
            let characterName = UserDefaults.standard.string(forKey: "representativeCharacter") ?? ""
            
            if characterName.isEmpty {
                Logger.error("No representative character name")
                return .failure(.invalidResponse)
            }
            
            Logger.debug("API Request: Fetching siblings for \(characterName)")
            
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // 기존 데이터를 초기화해야 하는 경우
            if clearExisting {
                try safeClearExistingData(modelContext: modelContext)
            }
            
            // API 호출 및 데이터 처리
            let encodedName = characterName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? characterName
            let url = URL(string: "\(baseURL)/characters/\(encodedName)/siblings")!
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            // 헤더 형식 개선
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.addValue("LOACheck/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
            
            Logger.debug("요청 URL: \(url.absoluteString)")
            Logger.debug("헤더 정보 - Accept: application/json, Authorization: Bearer [키길이:\(apiKey.count)]")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(.invalidResponse)
            }
            
            Logger.debug("HTTP 상태 코드: \(httpResponse.statusCode)")
            
            // 응답 내용 전체 로깅 (API 구조 변경 확인용)
            if let responseString = String(data: data, encoding: .utf8) {
                Logger.debug("전체 API 응답: \(responseString)")
            }
            
            switch httpResponse.statusCode {
            case 200:
                // JSON 구조 먼저 확인
                if let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    Logger.debug("JSON 배열 감지, 첫 번째 객체의 키들: \(jsonObject.first?.keys.joined(separator: ", ") ?? "없음")")
                    
                    // 각 객체의 구조를 확인
                    for (index, object) in jsonObject.enumerated() {
                        Logger.debug("객체 \(index): \(object)")
                        if index >= 2 { break } // 처음 3개만 로깅
                    }
                }
                
                let decoder = JSONDecoder()
                
                do {
                    let charactersData = try decoder.decode([CharacterResponse].self, from: data)
                    Logger.debug("성공적으로 \(charactersData.count)개 캐릭터 디코딩 완료")
                    
                    // 디코딩된 데이터 검증
                    for character in charactersData {
                        Logger.debug("캐릭터: \(character.characterName), 레벨: \(character.itemLevel), 클래스: \(character.characterClassName)")
                    }
                    
                    var allCharactersData = charactersData
                    
                    // 대표 캐릭터가 응답에 포함되어 있는지 확인
                    let hasRepresentativeCharacter = charactersData.contains { $0.characterName == characterName }
                    
                    if !hasRepresentativeCharacter {
                        Logger.debug("대표 캐릭터가 응답에 없음, 직접 요청 시도: \(characterName)")
                        // 단일 캐릭터 정보 가져오기 시도
                        if let singleCharacter = try await fetchSingleCharacter(name: characterName, apiKey: apiKey) {
                            allCharactersData.append(singleCharacter)
                        }
                    }
                    
                    // 기존 캐릭터 데이터 유지하면서 정보 업데이트
                    await updateExistingCharacters(charactersData: allCharactersData, modelContext: modelContext, clearExisting: clearExisting)
                    
                    let responseTimeMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
                    
                    // 성공 로그 및 분석
                    if !hasLoggedCharactersThisSession {
                        Analytics.logEvent("characters_loaded", parameters: [
                            "character_count": allCharactersData.count,
                            "avg_level": allCharactersData.isEmpty ? 0 : allCharactersData.reduce(0.0) { $0 + $1.itemLevel } / Double(allCharactersData.count),
                            "max_level": allCharactersData.max(by: { $0.itemLevel < $1.itemLevel })?.itemLevel ?? 0,
                            "load_method": clearExisting ? "full_refresh" : "update_existing",
                            "api_response_time_ms": responseTimeMs,
                            "load_success": true
                        ])
                        self.hasLoggedCharactersThisSession = true
                    }
                    
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
                Logger.error("인증 실패: API 키 확인 필요")
                return .failure(.unauthorized)
            case 403:
                Logger.error("접근 거부: 권한 부족")
                return .failure(.forbidden)
            case 429:
                Logger.error("요청 한도 초과")
                return .failure(.rateLimit)
            case 503:
                Logger.error("서비스 점검 중")
                return .failure(.serviceUnavailable)
            default:
                Logger.error("예상치 못한 상태 코드: \(httpResponse.statusCode)")
                return .failure(.unknown(httpResponse.statusCode))
            }
            
        } catch {
            // 오류 발생 시 이벤트 로깅
            Analytics.logEvent("characters_load_failed", parameters: [
                "error_message": error.localizedDescription,
                "api_key_provided": !apiKey.isEmpty,
                "network_connected": NetworkMonitorService.shared.isConnected
            ])
            Logger.error("API 요청 중 네트워크 오류", error: error)
            return .failure(.networkError(error))
        }
    }
    
    // MARK: - 추가 원정대 가져오기
    @MainActor
    func fetchAdditionalRoster(characterName: String, apiKey: String, modelContext: ModelContext) async -> Result<Int, APIError> {
        do {
            Logger.debug("API Request: Fetching additional roster for \(characterName)")
            
            // API 호출 및 데이터 처리
            let encodedName = characterName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? characterName
            let url = URL(string: "\(baseURL)/characters/\(encodedName)/siblings")!
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.addValue("LOACheck/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(.invalidResponse)
            }
            
            switch httpResponse.statusCode {
            case 200:
                let decoder = JSONDecoder()
                let charactersData = try decoder.decode([CharacterResponse].self, from: data)
                
                // 기존 데이터를 유지하면서 추가 캐릭터만 업데이트
                await updateExistingCharacters(charactersData: charactersData, modelContext: modelContext, clearExisting: false)
                
                return .success(charactersData.count)
                
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
            Logger.error("추가 원정대 API 오류", error: error)
            return .failure(.networkError(error))
        }
    }
    
    // MARK: - 단일 캐릭터 정보 업데이트 (아머리 API 사용)
    @MainActor
    func updateSingleCharacterViaArmory(
        name: String,
        apiKey: String,
        modelContext: ModelContext
    ) async -> Result<Bool, APIError> {
        do {
            Logger.debug("API Request: Updating character \(name) via armory profiles API")
            
            // 캐릭터 검색
            let fetchDescriptor = FetchDescriptor<CharacterModel>(
                predicate: #Predicate<CharacterModel> { character in
                    character.name == name
                }
            )
            
            let characters = try modelContext.fetch(fetchDescriptor)
            guard let character = characters.first else {
                return .failure(.documentNotFound)
            }
            
            // 아머리 프로필 API 호출
            let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
            let url = URL(string: "\(baseURL)/armories/characters/\(encodedName)/profiles")!
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.addValue("LOACheck/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(.invalidResponse)
            }
            
            switch httpResponse.statusCode {
            case 200:
                let decoder = JSONDecoder()
                
                do {
                    let profileData = try decoder.decode(CharacterProfileResponse.self, from: data)
                    
                    // 아이템 레벨 업데이트
                    let levelString = profileData.safeItemMaxLevel.replacingOccurrences(of: ",", with: "")
                    let level = Double(levelString) ?? character.level
                    
                    // 전투력 업데이트
                    let combatPowerString = profileData.safeCombatPower.replacingOccurrences(of: ",", with: "")
                    let combatPower = Double(combatPowerString) ?? character.combatPower
                    
                    // 캐릭터 정보 업데이트
                    character.server = profileData.safeServerName
                    character.characterClass = profileData.safeCharacterClassName
                    character.level = level
                    character.combatPower = combatPower
                    character.lastUpdated = Date()
                    
                    try modelContext.save()
                    
                    Logger.debug("캐릭터 '\(name)' 업데이트 완료 - 레벨: \(level), 전투력: \(combatPower)")
                    
                    return .success(true)
                    
                } catch {
                    Logger.error("아머리 API 디코딩 실패", error: error)
                    return .failure(.networkError(error))
                }
                
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
            Logger.error("아머리 API 요청 실패", error: error)
            return .failure(.networkError(error))
        }
    }
    
    // MARK: - 캐릭터 존재 여부 확인
    func validateCharacter(name: String, apiKey: String) async -> Result<Bool, APIError> {
        do {
            let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
            let url = URL(string: "\(baseURL)/characters/\(encodedName)")!
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.addValue("LOACheck/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(.invalidResponse)
            }
            
            switch httpResponse.statusCode {
            case 200:
                return .success(true)
            case 404:
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
    
    // MARK: - Public Helper Methods
    
    /// 단일 캐릭터 정보 조회 (외부에서 사용 가능)
    func fetchSingleCharacterInfo(name: String, apiKey: String) async throws -> CharacterResponse? {
        return try await fetchSingleCharacter(name: name, apiKey: apiKey)
    }
    
    // MARK: - Private Helper Methods
    
    // 기존 데이터를 안전하게 초기화
    @MainActor
    private func safeClearExistingData(modelContext: ModelContext) throws {
        // 순서대로 데이터 삭제 (참조 관계 고려)
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
    
    // 단일 캐릭터 정보 가져오기
    private func fetchSingleCharacter(name: String, apiKey: String) async throws -> CharacterResponse? {
        let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        let url = URL(string: "\(baseURL)/characters/\(encodedName)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("LOACheck/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return nil
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(CharacterResponse.self, from: data)
    }
    
    // 기존 캐릭터 데이터 업데이트
    @MainActor
    private func updateExistingCharacters(charactersData: [CharacterResponse], modelContext: ModelContext, clearExisting: Bool = false) async {
        
        // 기존 캐릭터 가져오기
        let fetchDescriptor = FetchDescriptor<CharacterModel>()
        let existingCharacters = (try? modelContext.fetch(fetchDescriptor)) ?? []
        
        // 새 캐릭터 추가 또는 업데이트
        for characterData in charactersData {
            let characterName = characterData.characterName
            
            // 기존 캐릭터 검색
            if let existingCharacter = existingCharacters.first(where: { $0.name == characterName }) {
                // 기존 캐릭터 업데이트
                existingCharacter.server = characterData.serverName
                existingCharacter.characterClass = characterData.characterClassName
                existingCharacter.level = characterData.itemLevel
                existingCharacter.combatPower = characterData.combatPower
                existingCharacter.lastUpdated = Date()
                
                Logger.debug("기존 캐릭터 업데이트: \(characterName), 전투력: \(characterData.combatPower)")
            } else {
                // 새 캐릭터 추가
                let newCharacter = CharacterModel(
                    name: characterName,
                    server: characterData.serverName,
                    characterClass: characterData.characterClassName,
                    level: characterData.itemLevel,
                    combatPower: characterData.combatPower
                )
                modelContext.insert(newCharacter)
                
                Logger.debug("새 캐릭터 추가: \(characterName), 전투력: \(characterData.combatPower)")
            }
        }
        
        // 변경사항 저장
        try? modelContext.save()
    }
}
