//
//  DataRepository.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 4/8/25.
//

import Foundation
import SwiftData
import FirebaseFirestore

/// 데이터 저장소 추상화 인터페이스
protocol DataRepository {
    // 캐릭터 관련
    func saveCharacter(_ character: CharacterModel) async throws
    func saveAllCharacters(_ characters: [CharacterModel]) async throws
    func fetchAllCharacters() async throws -> [CharacterModel]
    func fetchCharacter(name: String) async throws -> CharacterModel?
    func deleteCharacter(_ character: CharacterModel) async throws
    func deleteAllCharacters() async throws
    
    // 캐릭터 데이터 동기화
    func syncCharactersToCloud() async throws
    func syncCharactersFromCloud() async throws
}

/// 로컬 SwiftData 저장소 구현
class LocalDataRepository: DataRepository {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // 캐릭터 저장
    func saveCharacter(_ character: CharacterModel) async throws {
        // 이미 존재하는 캐릭터인지 확인
        if let existingCharacter = try await fetchCharacter(name: character.name) {
            // 기존 캐릭터 업데이트
            existingCharacter.server = character.server
            existingCharacter.characterClass = character.characterClass
            existingCharacter.level = character.level
            existingCharacter.imageURL = character.imageURL
            existingCharacter.isHidden = character.isHidden
            existingCharacter.isGoldEarner = character.isGoldEarner
            existingCharacter.lastUpdated = Date()
            
            // 추가 골드 맵 복사
            existingCharacter.additionalGoldMap = character.additionalGoldMap
            
            // 일일 숙제 및 레이드 업데이트는 선택적으로 진행 (이미 진행 중인 작업 유지)
        } else {
            // 새 캐릭터 추가
            modelContext.insert(character)
        }
        
        // 변경사항 저장
        try modelContext.save()
    }
    
    // 모든 캐릭터 저장
    func saveAllCharacters(_ characters: [CharacterModel]) async throws {
        for character in characters {
            try await saveCharacter(character)
        }
    }
    
    // 모든 캐릭터 가져오기
    func fetchAllCharacters() async throws -> [CharacterModel] {
        let descriptor = FetchDescriptor<CharacterModel>()
        return try modelContext.fetch(descriptor)
    }
    
    // 특정 이름의 캐릭터 가져오기
    func fetchCharacter(name: String) async throws -> CharacterModel? {
        let descriptor = FetchDescriptor<CharacterModel>(
            predicate: #Predicate<CharacterModel> { $0.name == name }
        )
        
        let characters = try modelContext.fetch(descriptor)
        return characters.first
    }
    
    // 캐릭터 삭제
    func deleteCharacter(_ character: CharacterModel) async throws {
        modelContext.delete(character)
        try modelContext.save()
    }
    
    // 모든 캐릭터 삭제
    func deleteAllCharacters() async throws {
        let descriptor = FetchDescriptor<CharacterModel>()
        let characters = try modelContext.fetch(descriptor)
        
        for character in characters {
            modelContext.delete(character)
        }
        
        try modelContext.save()
    }
    
    // 클라우드로 캐릭터 데이터 동기화 (로컬 -> 클라우드)
    func syncCharactersToCloud() async throws {
        // 로컬 저장소만 사용하는 경우 구현할 필요 없음
        throw DataRepositoryError.operationNotSupported("클라우드 동기화가 지원되지 않습니다")
    }
    
    // 클라우드에서 캐릭터 데이터 동기화 (클라우드 -> 로컬)
    func syncCharactersFromCloud() async throws {
        // 로컬 저장소만 사용하는 경우 구현할 필요 없음
        throw DataRepositoryError.operationNotSupported("클라우드 동기화가 지원되지 않습니다")
    }
}

/// Firebase 클라우드 저장소 구현
class CloudDataRepository: DataRepository {
    private let userId: String
    private let localRepository: LocalDataRepository
    
    init(userId: String, modelContext: ModelContext) {
        self.userId = userId
        self.localRepository = LocalDataRepository(modelContext: modelContext)
    }
    
    // 캐릭터 저장 (로컬 및 클라우드)
    func saveCharacter(_ character: CharacterModel) async throws {
        // 먼저 로컬에 저장
        try await localRepository.saveCharacter(character)
        
        // 그 다음 클라우드에 동기화
        try await syncCharactersToCloud()
    }
    
    // 모든 캐릭터 저장 (로컬 및 클라우드)
    func saveAllCharacters(_ characters: [CharacterModel]) async throws {
        // 먼저 로컬에 저장
        try await localRepository.saveAllCharacters(characters)
        
        // 그 다음 클라우드에 동기화
        try await syncCharactersToCloud()
    }
    
    // 모든 캐릭터 가져오기 (로컬)
    func fetchAllCharacters() async throws -> [CharacterModel] {
        return try await localRepository.fetchAllCharacters()
    }
    
    // 특정 이름의 캐릭터 가져오기 (로컬)
    func fetchCharacter(name: String) async throws -> CharacterModel? {
        return try await localRepository.fetchCharacter(name: name)
    }
    
    // 캐릭터 삭제 (로컬 및 클라우드)
    func deleteCharacter(_ character: CharacterModel) async throws {
        // 먼저 로컬에서 삭제
        try await localRepository.deleteCharacter(character)
        
        // 그 다음 클라우드에 동기화
        try await syncCharactersToCloud()
    }
    
    // 모든 캐릭터 삭제 (로컬 및 클라우드)
    func deleteAllCharacters() async throws {
        // 먼저 로컬에서 삭제
        try await localRepository.deleteAllCharacters()
        
        // 클라우드에서도 모든 캐릭터 삭제
        guard !userId.isEmpty else {
            throw DataRepositoryError.notAuthenticated
        }
        
        // Firebase에서 모든 캐릭터 데이터 삭제
        let charactersRef = Firestore.firestore().collection("users").document(userId).collection("characters")
        let snapshot = try await charactersRef.getDocuments()
        
        if snapshot.documents.isEmpty {
            return
        }
        
        let batch = Firestore.firestore().batch()
        snapshot.documents.forEach { doc in
            batch.deleteDocument(doc.reference)
        }
        
        try await batch.commit()
        
        // 클라우드 동기화
        try await syncCharactersToCloud()
    }
    
    // 클라우드로 캐릭터 데이터 동기화 (로컬 -> 클라우드)
    func syncCharactersToCloud() async throws {
        guard !userId.isEmpty else {
            throw DataRepositoryError.notAuthenticated
        }
        
        // 로컬 캐릭터 가져오기
        let characters = try await localRepository.fetchAllCharacters()
        
        // Firebase에 모든 캐릭터 저장
        try await FirebaseRepository.shared.saveCharacters(characters)
    }
    
    // 클라우드에서 캐릭터 데이터 동기화 (클라우드 -> 로컬)
    func syncCharactersFromCloud() async throws {
        guard !userId.isEmpty else {
            throw DataRepositoryError.notAuthenticated
        }
        
        // Firebase에서 캐릭터 가져오기
        let cloudCharacters = try await FirebaseRepository.shared.fetchCharacters()
        
        // 로컬 데이터 삭제 후 클라우드 데이터로 대체
        try await localRepository.deleteAllCharacters()
        try await localRepository.saveAllCharacters(cloudCharacters)
    }
}

/// 데이터 저장소 팩토리 - 컨텍스트에 따라 적절한 저장소 제공
class DataRepositoryFactory {
    static func getRepository(modelContext: ModelContext) -> DataRepository {
        if AuthManager.shared.isLoggedIn, let userId = AuthManager.shared.currentUser?.id {
            return CloudDataRepository(userId: userId, modelContext: modelContext)
        } else {
            return LocalDataRepository(modelContext: modelContext)
        }
    }
}

// 데이터 저장소 관련 오류 정의
enum DataRepositoryError: Error, LocalizedError {
    case operationNotSupported(String)
    case notAuthenticated
    case dataError(String)
    
    var errorDescription: String? {
        switch self {
        case .operationNotSupported(let message):
            return message
        case .notAuthenticated:
            return "사용자 인증이 필요합니다."
        case .dataError(let message):
            return message
        }
    }
}
