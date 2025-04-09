//
//  DataSyncManager.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 4/8/25.
//

import Foundation
import SwiftData
import Combine

/// 데이터 동기화 작업을 관리하는 매니저 클래스
class DataSyncManager: ObservableObject {
    static let shared = DataSyncManager()
    
    // 동기화 상태
    @Published var isSyncing = false
    @Published var lastSyncTime: Date?
    @Published var syncError: Error?
    @Published var hasPendingChanges = false
    
    // 충돌 해결 상태
    @Published var hasConflicts = false
    @Published var conflictsResolved = false
    
    // 인증 매니저 구독
    private var cancellables = Set<AnyCancellable>()
    var modelContext: ModelContext?
    
    // 동기화 전략 선택
    enum SyncStrategy {
        case localOverCloud  // 로컬 데이터 우선
        case cloudOverLocal  // 클라우드 데이터 우선
        case merge           // 데이터 병합 (최신 데이터 기준)
        case manual          // 수동 선택
    }
    
    @Published var syncStrategy: SyncStrategy = .merge
    
    private init() {
        setupAuthSubscriptions()
    }
    
    // 인증 상태 변경 구독 설정
    private func setupAuthSubscriptions() {
        // 로그인 상태 변경 관찰
        AuthManager.shared.$isLoggedIn
            .dropFirst() // 초기값 무시
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoggedIn in
                if isLoggedIn {
                    // 로그인했을 때 초기 동기화 수행
                    if AuthManager.shared.isFirstTimeLogin {
                        self?.performInitialSync()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // ModelContext 설정
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    // 초기 동기화 수행 (로그인 직후)
    func performInitialSync() {
        guard let modelContext = modelContext else {
            DispatchQueue.main.async {
                self.syncError = DataSyncError.contextNotSet
            }
            return
        }
        
        Task { @MainActor in
            do {
                isSyncing = true
                syncError = nil
                
                // 로컬 데이터 존재 여부 확인
                let localCharacterCount = try countLocalCharacters(modelContext: modelContext)
                
                if localCharacterCount > 0 {
                    // 로컬 데이터가 있는 경우, 충돌 가능성을 확인하고 동기화 전략 결정
                    let cloudCharacterCount = try await countCloudCharacters()
                    
                    if cloudCharacterCount > 0 {
                        // 양쪽 모두 데이터가 있을 경우 충돌 가능성 있음
                        hasConflicts = true
                        
                        // 기본 전략 적용 (병합)
                        switch syncStrategy {
                        case .localOverCloud:
                            try await pushToCloud()
                        case .cloudOverLocal:
                            try await pullFromCloud()
                        case .merge:
                            try await performMergeSync()
                        case .manual:
                            // 사용자에게 선택을 요청하기 위해 동기화 중단
                            isSyncing = false
                            return
                        }
                    } else {
                        // 클라우드 데이터가 없는 경우 로컬 데이터를 업로드
                        try await pushToCloud()
                    }
                } else {
                    // 로컬 데이터가 없는 경우 클라우드 데이터를 다운로드
                    try await pullFromCloud()
                }
                
                // 초기 동기화 완료 표시
                AuthManager.shared.markInitialSyncComplete()
                
                lastSyncTime = Date()
                isSyncing = false
                hasPendingChanges = false
                hasConflicts = false
                conflictsResolved = true
            } catch {
                syncError = error
                isSyncing = false
            }
        }
    }
    
    // 수동 동기화 실행 (양방향)
    func performManualSync() async -> Bool {
        guard let modelContext = modelContext else {
            await MainActor.run {
                self.syncError = DataSyncError.contextNotSet
            }
            return false
        }
        
        guard AuthManager.shared.isLoggedIn else {
            await MainActor.run {
                self.syncError = DataSyncError.notAuthenticated
            }
            return false
        }
        
        do {
            await MainActor.run {
                self.isSyncing = true
                self.syncError = nil
            }
            
            // 양방향 동기화 전 데이터 확인
            let localCharacterCount = try countLocalCharacters(modelContext: modelContext)
            let cloudCharacterCount = try await countCloudCharacters()
            
            if localCharacterCount > 0 && cloudCharacterCount > 0 {
                // 충돌 가능성이 있는 경우, 병합 동기화 수행
                try await performMergeSync()
            } else if localCharacterCount > 0 {
                // 로컬 데이터만 있는 경우
                try await pushToCloud()
            } else if cloudCharacterCount > 0 {
                // 클라우드 데이터만 있는 경우
                try await pullFromCloud()
            } else {
                // 양쪽 모두 데이터가 없는 경우, 동기화 완료로 간주
                Logger.info("양쪽 모두 데이터가 없습니다. 동기화 완료.")
            }
            
            await MainActor.run {
                self.lastSyncTime = Date()
                self.isSyncing = false
                self.hasPendingChanges = false
                self.hasConflicts = false
                self.conflictsResolved = true
            }
            
            return true
        } catch {
            await MainActor.run {
                self.syncError = error
                self.isSyncing = false
            }
            return false
        }
    }
    
    // 병합 동기화 수행 (타임스탬프 기반)
    private func performMergeSync() async throws {
        guard let modelContext = modelContext else {
            throw DataSyncError.contextNotSet
        }
        
        // 1. 클라우드 데이터 가져오기
        let repository = DataRepositoryFactory.getRepository(modelContext: modelContext)
        let cloudCharacters = try await FirebaseRepository.shared.fetchCharacters()
        
        // 2. 로컬 데이터 가져오기
        let descriptor = FetchDescriptor<CharacterModel>()
        let localCharacters = try modelContext.fetch(descriptor)
        
        // 3. 데이터 병합
        let mergedCharacters = mergeCharacters(local: localCharacters, cloud: cloudCharacters)
        
        // 4. 로컬 데이터베이스 업데이트
        try updateLocalDatabase(modelContext: modelContext, mergedCharacters: mergedCharacters)
        
        // 5. 클라우드 데이터베이스 업데이트
        try await repository.saveAllCharacters(mergedCharacters)
        
        Logger.info("병합 동기화 완료: \(mergedCharacters.count)개 캐릭터")
    }
    
    // 캐릭터 데이터 병합 (타임스탬프 기준)
    private func mergeCharacters(local: [CharacterModel], cloud: [CharacterModel]) -> [CharacterModel] {
        var mergedMap: [String: CharacterModel] = [:]
        
        // 로컬 캐릭터 맵 생성
        var localCharacterMap: [String: CharacterModel] = [:]
        for character in local {
            localCharacterMap[character.name] = character
        }
        
        // 클라우드 캐릭터 맵 생성
        var cloudCharacterMap: [String: CharacterModel] = [:]
        for character in cloud {
            cloudCharacterMap[character.name] = character
        }
        
        // 1. 양쪽에 모두 있는 캐릭터 병합 (최신 타임스탬프 기준)
        let commonNames = Set(localCharacterMap.keys).intersection(Set(cloudCharacterMap.keys))
        for name in commonNames {
            guard let localChar = localCharacterMap[name], let cloudChar = cloudCharacterMap[name] else {
                continue
            }
            
            if localChar.lastUpdated > cloudChar.lastUpdated {
                // 로컬 데이터가 더 최신
                mergedMap[name] = localChar
            } else {
                // 클라우드 데이터가 더 최신
                mergedMap[name] = cloudChar
            }
        }
        
        // 2. 로컬에만 있는 캐릭터 추가
        let localOnlyNames = Set(localCharacterMap.keys).subtracting(Set(cloudCharacterMap.keys))
        for name in localOnlyNames {
            if let localChar = localCharacterMap[name] {
                mergedMap[name] = localChar
            }
        }
        
        // 3. 클라우드에만 있는 캐릭터 추가
        let cloudOnlyNames = Set(cloudCharacterMap.keys).subtracting(Set(localCharacterMap.keys))
        for name in cloudOnlyNames {
            if let cloudChar = cloudCharacterMap[name] {
                mergedMap[name] = cloudChar
            }
        }
        
        return Array(mergedMap.values)
    }
    
    // 로컬 데이터베이스 업데이트
    private func updateLocalDatabase(modelContext: ModelContext, mergedCharacters: [CharacterModel]) throws {
        // 현재 로컬 캐릭터 가져오기
        let descriptor = FetchDescriptor<CharacterModel>()
        let localCharacters = try modelContext.fetch(descriptor)
        
        // 로컬 캐릭터 맵 생성
        var localCharacterMap: [String: CharacterModel] = [:]
        for character in localCharacters {
            localCharacterMap[character.name] = character
        }
        
        // 병합된 캐릭터로 업데이트
        for mergedChar in mergedCharacters {
            if let existingChar = localCharacterMap[mergedChar.name] {
                // 기존 캐릭터 업데이트
                updateCharacterProperties(from: mergedChar, to: existingChar)
            } else {
                // 새 캐릭터 추가
                modelContext.insert(mergedChar)
            }
        }
        
        // 병합 리스트에 없는 로컬 캐릭터 삭제 (이미지제외)
        let mergedNames = Set(mergedCharacters.map { $0.name })
        for localChar in localCharacters {
            if !mergedNames.contains(localChar.name) {
                modelContext.delete(localChar)
            }
        }
        
        try modelContext.save()
        Logger.info("로컬 데이터베이스 업데이트 완료")
    }
    
    // 캐릭터 속성 업데이트
    private func updateCharacterProperties(from source: CharacterModel, to target: CharacterModel) {
        target.server = source.server
        target.characterClass = source.characterClass
        target.level = source.level
        target.imageURL = source.imageURL
        target.isHidden = source.isHidden
        target.isGoldEarner = source.isGoldEarner
        target.lastUpdated = source.lastUpdated
        target.additionalGoldMap = source.additionalGoldMap
        
        // 일일 숙제 업데이트
        if let sourceTasks = source.dailyTasks {
            if target.dailyTasks == nil {
                target.dailyTasks = []
            }
            
            // 기존 태스크 맵 생성
            var targetTaskMap: [DailyTask.TaskType: DailyTask] = [:]
            if let targetTasks = target.dailyTasks {
                for task in targetTasks {
                    targetTaskMap[task.type] = task
                }
            }
            
            // 소스 태스크로 업데이트
            for sourceTask in sourceTasks {
                if let targetTask = targetTaskMap[sourceTask.type] {
                    // 기존 태스크 업데이트
                    targetTask.completionCount = sourceTask.completionCount
                    targetTask.lastCompletedAt = sourceTask.lastCompletedAt
                    targetTask.restingPoints = sourceTask.restingPoints
                    targetTask.usedRestingPoint1 = sourceTask.usedRestingPoint1
                    targetTask.usedRestingPoint2 = sourceTask.usedRestingPoint2
                    targetTask.usedRestingPoint3 = sourceTask.usedRestingPoint3
                } else {
                    // 새 태스크 추가
                    target.dailyTasks?.append(sourceTask)
                }
            }
        }
        
        // 레이드 관문 업데이트
        if let sourceGates = source.raidGates {
            if target.raidGates == nil {
                target.raidGates = []
            }
            
            // 기존 관문 맵 생성
            var targetGateMap: [String: RaidGate] = [:]
            if let targetGates = target.raidGates {
                for gate in targetGates {
                    let key = "\(gate.raid)-\(gate.gate)-\(gate.difficulty)"
                    targetGateMap[key] = gate
                }
            }
            
            // 소스 관문으로 업데이트
            for sourceGate in sourceGates {
                let key = "\(sourceGate.raid)-\(sourceGate.gate)-\(sourceGate.difficulty)"
                if let targetGate = targetGateMap[key] {
                    // 기존 관문 업데이트
                    targetGate.goldReward = sourceGate.goldReward
                    targetGate.isCompleted = sourceGate.isCompleted
                    targetGate.lastCompletedAt = sourceGate.lastCompletedAt
                    targetGate.additionalGold = sourceGate.additionalGold
                } else {
                    // 새 관문 추가
                    target.raidGates?.append(sourceGate)
                }
            }
            
            // 소스에 없는 관문 제거
            let sourceKeys = sourceGates.map { "\($0.raid)-\($0.gate)-\($0.difficulty)" }
            if let targetGates = target.raidGates {
                target.raidGates = targetGates.filter { gate in
                    let key = "\(gate.raid)-\(gate.gate)-\(gate.difficulty)"
                    return sourceKeys.contains(key)
                }
            }
        }
    }
    
    // 클라우드에서 데이터 가져오기 (단방향: 클라우드 -> 로컬)
    func pullFromCloud() async -> Bool {
        guard let modelContext = modelContext else {
            await MainActor.run {
                self.syncError = DataSyncError.contextNotSet
            }
            return false
        }
        
        guard AuthManager.shared.isLoggedIn else {
            await MainActor.run {
                self.syncError = DataSyncError.notAuthenticated
            }
            return false
        }
        
        do {
            await MainActor.run {
                self.isSyncing = true
                self.syncError = nil
            }
            
            let repository = DataRepositoryFactory.getRepository(modelContext: modelContext)
            try await repository.syncCharactersFromCloud()
            
            await MainActor.run {
                self.lastSyncTime = Date()
                self.isSyncing = false
                self.hasPendingChanges = false
            }
            
            return true
        } catch {
            await MainActor.run {
                self.syncError = error
                self.isSyncing = false
            }
            return false
        }
    }
    
    // 로컬 데이터를 클라우드로 업로드 (단방향: 로컬 -> 클라우드)
    func pushToCloud() async -> Bool {
        guard let modelContext = modelContext else {
            await MainActor.run {
                self.syncError = DataSyncError.contextNotSet
            }
            return false
        }
        
        guard AuthManager.shared.isLoggedIn else {
            await MainActor.run {
                self.syncError = DataSyncError.notAuthenticated
            }
            return false
        }
        
        do {
            await MainActor.run {
                self.isSyncing = true
                self.syncError = nil
            }
            
            let repository = DataRepositoryFactory.getRepository(modelContext: modelContext)
            try await repository.syncCharactersToCloud()
            
            await MainActor.run {
                self.lastSyncTime = Date()
                self.isSyncing = false
                self.hasPendingChanges = false
            }
            
            return true
        } catch {
            await MainActor.run {
                self.syncError = error
                self.isSyncing = false
            }
            return false
        }
    }
    
    // 로컬 변경사항 표시
    func markLocalChanges() {
        DispatchQueue.main.async {
            self.hasPendingChanges = true
        }
    }
    
    // 오류 지우기
    func clearError() {
        DispatchQueue.main.async {
            self.syncError = nil
        }
    }
    
    // 로컬 캐릭터 개수 카운트
    private func countLocalCharacters(modelContext: ModelContext) throws -> Int {
        let descriptor = FetchDescriptor<CharacterModel>()
        let localCharacters = try modelContext.fetch(descriptor)
        return localCharacters.count
    }
    
    // 클라우드 캐릭터 개수 카운트
    private func countCloudCharacters() async throws -> Int {
        do {
            let characters = try await FirebaseRepository.shared.fetchCharacters()
            return characters.count
        } catch {
            Logger.error("클라우드 캐릭터 개수 확인 실패: \(error.localizedDescription)")
            throw error
        }
    }
    
    // 현재 동기화 상태 정보 문자열 반환
    func getSyncStatusDescription() -> String {
        var status = ""
        
        if isSyncing {
            status = "동기화 중..."
        } else if let error = syncError {
            status = "오류: \(error.localizedDescription)"
        } else if hasPendingChanges {
            status = "동기화 필요"
        } else if let lastSync = lastSyncTime {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .short
            status = "마지막 동기화: \(formatter.localizedString(for: lastSync, relativeTo: Date()))"
        } else {
            status = "동기화되지 않음"
        }
        
        return status
    }
}

// 동기화 관련 오류 정의
enum DataSyncError: Error, LocalizedError {
    case contextNotSet
    case notAuthenticated
    case syncFailed(String)
    case conflictDetected
    case networkUnavailable
    
    var errorDescription: String? {
        switch self {
        case .contextNotSet:
            return "데이터 컨텍스트가 설정되지 않았습니다."
        case .notAuthenticated:
            return "동기화를 위해 로그인이 필요합니다."
        case .syncFailed(let message):
            return "동기화 실패: \(message)"
        case .conflictDetected:
            return "데이터 충돌이 발견되었습니다. 동기화 방법을 선택해주세요."
        case .networkUnavailable:
            return "네트워크 연결을 확인할 수 없습니다."
        }
    }
}
