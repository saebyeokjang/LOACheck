//
//  DataSyncManager.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 4/8/25.
//

import Foundation
import SwiftData
import Combine
import SwiftUI

/// 데이터 동기화 작업을 관리하는 매니저 클래스
class DataSyncManager: ObservableObject {
    static let shared = DataSyncManager()
    private var syncTimer: Timer?
    private var lastChangeTimestamp: Date?
    
    // 상태 관리용 변수
    private var isSyncInProgress = false
    
    @Published var useAutoSync: Bool = true
    
    // 동기화 상태
    @Published var isSyncing = false
    @Published var lastSyncTime: Date?
    @Published var syncError: Error?
    @Published var hasPendingChanges = false
    
    // 충돌 감지 관련 속성
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
    
    @Published var syncStrategy: SyncStrategy = .localOverCloud
    
    // 마지막 동기화 시도 시간
    private var lastSyncAttempt: Date = .distantPast
    // 최소 동기화 간격 (초)
    private let minSyncInterval: TimeInterval = 5.0
    
    private init() {
        if UserDefaults.standard.object(forKey: "useAutoSync") != nil {
            self.useAutoSync = UserDefaults.standard.bool(forKey: "useAutoSync")
        }
        setupAuthSubscriptions()
    }
    
    func setAutoSync(_ value: Bool) {
        useAutoSync = value
        UserDefaults.standard.set(value, forKey: "useAutoSync")
    }
    
    // MARK: - MainActor를 활용한 상태 관리 메서드
    
    // 동기화 상태 확인
    @MainActor
    private func isCurrentlySyncing() -> Bool {
        return isSyncInProgress
    }
    
    // 동기화 상태 설정
    @MainActor
    private func setIsSyncing(_ value: Bool) {
        isSyncInProgress = value
    }
    
    // 백그라운드에서 안전하게 동기화를 실행하는 메소드 개선
    func safeBackgroundSync() async -> Bool {
        Logger.debug("safeBackgroundSync 호출됨")
        
        // 이미 동기화 중인지 확인
        if await MainActor.run(body: { self.isSyncInProgress }) {
            return false
        }
        
        // 최소 동기화 간격 체크
        let now = Date()
        if now.timeIntervalSince(lastSyncAttempt) < minSyncInterval {
            // 간격을 5초에서 1초로 줄이기
            return false
        }
        
        lastSyncAttempt = now
        
        // 동기화 상태 설정
        await MainActor.run {
            self.isSyncInProgress = true
        }
        
        // 함수 종료 시 상태 초기화를 위한 defer
        defer {
            Task { @MainActor in
                self.isSyncInProgress = false
            }
        }
        
        // 로그인 상태 확인
        let isLoggedIn = AuthManager.shared.isLoggedIn
        
        // 변경사항 있는지 확인
        let hasPendingChanges = await MainActor.run { self.hasPendingChanges }
        
        // 네트워크 연결 확인
        let isConnected = NetworkMonitorService.shared.isConnected
        
        // 모든 조건이 충족되는 경우에만 실행
        if isLoggedIn && hasPendingChanges && isConnected {
            return await uploadToServer()
        }
        
        return false
    }
    
    // 서버로 데이터 업로드 메소드 개선
    func uploadToServer() async -> Bool {
        // ModelContext 확인
        let hasContext = await MainActor.run { self.modelContext != nil }
        guard hasContext else {
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
        
        // 이미 동기화 중인지 확인
        let isSyncing = await MainActor.run { self.isSyncInProgress }
        if isSyncing {
            return false
        }
        
        // 동기화 상태 설정
        await MainActor.run {
            self.isSyncInProgress = true
        }
        
        // 함수 종료 시 상태 초기화를 위한 defer
        defer {
            Task { @MainActor in
                self.isSyncInProgress = false
            }
        }
        
        // 로컬 데이터를 서버에 업로드하는 로직 (로컬 우선 방식)
        do {
            await MainActor.run {
                self.isSyncing = true
                self.syncError = nil
            }
            
            // 로컬 캐릭터 가져오기 - 메인 액터에서 실행
            let localCharacters = try await MainActor.run {
                guard let modelContext = self.modelContext else {
                    throw DataSyncError.contextNotSet
                }
                
                let descriptor = FetchDescriptor<CharacterModel>()
                return try modelContext.fetch(descriptor)
            }
            
            if !localCharacters.isEmpty {
                // 서버에 업로드
                try await FirebaseRepository.shared.saveCharacters(localCharacters)
                
                await MainActor.run {
                    self.lastSyncTime = Date()
                    self.isSyncing = false
                    self.hasPendingChanges = false
                    self.hasConflicts = false
                    Logger.info("서버 업로드 완료: \(localCharacters.count)개 캐릭터")
                }
                return true
            } else {
                await MainActor.run {
                    self.isSyncing = false
                    Logger.info("업로드할 캐릭터가 없음")
                }
                return true
            }
        } catch {
            await MainActor.run {
                self.syncError = error
                self.isSyncing = false
                Logger.error("서버 업로드 실패", error: error)
            }
            return false
        }
    }
    
    // 데이터 병합 처리
    private func mergeData() async -> Bool {
        // 메인 액터에서 ModelContext 확인
        let hasContext = await MainActor.run { self.modelContext != nil }
        guard hasContext else {
            await MainActor.run {
                self.syncError = DataSyncError.contextNotSet
            }
            return false
        }
        
        do {
            await MainActor.run {
                self.isSyncing = true
                self.syncError = nil
            }
            
            // 로컬 캐릭터 가져오기 - 메인 액터에서 실행
            let localCharacters = try await MainActor.run {
                guard let modelContext = self.modelContext else {
                    throw DataSyncError.contextNotSet
                }
                
                let descriptor = FetchDescriptor<CharacterModel>()
                return try modelContext.fetch(descriptor)
            }
            
            // 클라우드 캐릭터 가져오기
            let cloudCharacters = try await FirebaseRepository.shared.fetchCharacters()
            
            // 병합 수행 - 메인 액터에서 로컬 데이터 업데이트
            await MainActor.run {
                guard let modelContext = self.modelContext else { return }
                
                // 병합 작업
                let mergedCharacters = self.mergeCharacters(localCharacters: localCharacters, cloudCharacters: cloudCharacters)
                
                // 로컬 데이터 업데이트
                for character in localCharacters {
                    modelContext.delete(character)
                }
                
                for character in mergedCharacters {
                    modelContext.insert(character)
                }
                
                do {
                    try modelContext.save()
                } catch {
                    Logger.error("데이터 병합 중 로컬 저장 실패", error: error)
                }
            }
            
            // 병합된 데이터를 클라우드에 업로드
            let mergedCharacters = try await MainActor.run {
                guard let modelContext = self.modelContext else {
                    throw DataSyncError.contextNotSet
                }
                
                let descriptor = FetchDescriptor<CharacterModel>()
                return try modelContext.fetch(descriptor)
            }
            
            try await FirebaseRepository.shared.saveCharacters(mergedCharacters)
            
            await MainActor.run {
                self.lastSyncTime = Date()
                self.isSyncing = false
                self.hasPendingChanges = false
                self.hasConflicts = false
                self.conflictsResolved = true
                Logger.info("데이터 병합 및 업로드 완료: \(mergedCharacters.count)개 캐릭터")
            }
            
            return true
        } catch {
            await MainActor.run {
                self.syncError = error
                self.isSyncing = false
                Logger.error("데이터 병합 실패", error: error)
            }
            return false
        }
    }
    
    // 캐릭터 데이터 병합 (최신 타임스탬프 기준)
    private func mergeCharacters(localCharacters: [CharacterModel], cloudCharacters: [CharacterModel]) -> [CharacterModel] {
        // 캐릭터 이름으로 매핑
        var characterByName = [String: CharacterModel]()
        
        // 먼저 로컬 캐릭터 추가
        for localChar in localCharacters {
            characterByName[localChar.name] = localChar
        }
        
        // 클라우드 캐릭터와 병합 (최신 데이터 우선)
        for cloudChar in cloudCharacters {
            if let localChar = characterByName[cloudChar.name] {
                // 두 캐릭터 모두 존재하는 경우, 최신 데이터로 업데이트
                if cloudChar.lastUpdated > localChar.lastUpdated {
                    characterByName[cloudChar.name] = cloudChar
                } else {
                    // 로컬 캐릭터가 더 최신이거나 동일한 경우, 특정 데이터만 병합
                    mergeRaidGates(localChar: localChar, cloudChar: cloudChar)
                }
            } else {
                // 로컬에 없는 캐릭터는 추가
                characterByName[cloudChar.name] = cloudChar
            }
        }
        
        return Array(characterByName.values)
    }
    
    // 레이드 관문 데이터 병합
    private func mergeRaidGates(localChar: CharacterModel, cloudChar: CharacterModel) {
        guard let localGates = localChar.raidGates, let cloudGates = cloudChar.raidGates else {
            return
        }
        
        // 관문 ID로 매핑
        var gateMap = Dictionary(grouping: localGates, by: { "\($0.raid)-\($0.gate)-\($0.difficulty)" })
        
        // 클라우드 관문 데이터와 병합
        for cloudGate in cloudGates {
            let key = "\(cloudGate.raid)-\(cloudGate.gate)-\(cloudGate.difficulty)"
            
            if let localGateArray = gateMap[key], let localGate = localGateArray.first {
                // 완료 상태는 OR 연산으로 병합 (한쪽이라도 완료되었으면 완료)
                localGate.isCompleted = localGate.isCompleted || cloudGate.isCompleted
                
                // 마지막 완료 시간은 최신 시간으로
                if let cloudTime = cloudGate.lastCompletedAt, let localTime = localGate.lastCompletedAt {
                    localGate.lastCompletedAt = cloudTime > localTime ? cloudTime : localTime
                } else if cloudGate.lastCompletedAt != nil {
                    localGate.lastCompletedAt = cloudGate.lastCompletedAt
                }
            } else {
                // 로컬에 없는 관문은 추가
                if let index = localChar.raidGates?.firstIndex(where: { $0.raid == cloudGate.raid && $0.gate > cloudGate.gate }) {
                    localChar.raidGates?.insert(cloudGate, at: index)
                } else {
                    localChar.raidGates?.append(cloudGate)
                }
            }
        }
    }
    
    // 클라우드 캐릭터 가져오기
    private func fetchCloudCharacters() async throws -> [CharacterModel] {
        do {
            return try await FirebaseRepository.shared.fetchCharacters()
        } catch {
            Logger.error("클라우드 캐릭터 가져오기 실패: \(error.localizedDescription)")
            throw error
        }
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
    
    /// 서버에서 데이터 복구 (사용자가 수동으로 호출)
    func pullFromCloud() async -> Bool {
        // 메인 액터에서 ModelContext 확인
        let hasContext = await MainActor.run { self.modelContext != nil }
        guard hasContext else {
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
        
        // 이미 동기화 중인지 확인
        let isSyncing = await MainActor.run { self.isSyncInProgress }
        if isSyncing {
            return false
        }
        
        // 동기화 상태 설정
        await MainActor.run {
            self.isSyncInProgress = true
        }
        
        // 함수 종료 시 상태 초기화를 위한 defer
        defer {
            Task { @MainActor in
                self.isSyncInProgress = false
            }
        }
        
        do {
            await MainActor.run {
                self.isSyncing = true
                self.syncError = nil
            }
            
            // 서버에서 캐릭터 가져오기
            let serverCharacters = try await FirebaseRepository.shared.fetchCharacters()
            
            if !serverCharacters.isEmpty {
                // 안전한 데이터 교체를 위해 메인 액터에서 처리
                try await MainActor.run {
                    guard let modelContext = self.modelContext else {
                        throw DataSyncError.contextNotSet
                    }
                    
                    // 1. 하위 객체(DailyTask, RaidGate)부터 삭제
                    let taskDescriptor = FetchDescriptor<DailyTask>()
                    let tasks = try modelContext.fetch(taskDescriptor)
                    for task in tasks { modelContext.delete(task) }
                    
                    let gateDescriptor = FetchDescriptor<RaidGate>()
                    let gates = try modelContext.fetch(gateDescriptor)
                    for gate in gates { modelContext.delete(gate) }
                    
                    // 2. 먼저 중간 저장
                    try modelContext.save()
                    
                    // 3. 캐릭터 객체 삭제
                    let charDescriptor = FetchDescriptor<CharacterModel>()
                    let characters = try modelContext.fetch(charDescriptor)
                    for character in characters { modelContext.delete(character) }
                    
                    // 4. 다시 저장
                    try modelContext.save()
                    
                    // 5. 서버 데이터 삽입
                    for character in serverCharacters {
                        modelContext.insert(character)
                    }
                    
                    // 6. 최종 저장
                    try modelContext.save()
                }
                
                await MainActor.run {
                    self.lastSyncTime = Date()
                    self.isSyncing = false
                    self.hasPendingChanges = false
                    self.hasConflicts = false
                    self.conflictsResolved = true
                    Logger.info("서버에서 복구 완료: \(serverCharacters.count)개 캐릭터")
                }
                return true
            } else {
                await MainActor.run {
                    self.isSyncing = false
                    Logger.info("서버에 복구할 캐릭터가 없음")
                }
                return false
            }
        } catch {
            await MainActor.run {
                self.syncError = error
                self.isSyncing = false
                Logger.error("서버에서 복구 실패", error: error)
            }
            return false
        }
    }
    
    // 호환성을 위한 기존 메소드
    func performManualSync() async -> Bool {
        // 네트워크 연결과 로그인 상태 확인
        if !NetworkMonitorService.shared.isConnected || !AuthManager.shared.isLoggedIn {
            return false
        }
        
        // 동기화 전략을 로컬 우선으로 강제 설정
        await MainActor.run {
            self.syncStrategy = .localOverCloud
        }
        
        // 로컬 데이터 → 클라우드 방향으로만 동기화
        return await uploadToServer()
    }
    
    func pushToCloud() async -> Bool {
        return await uploadToServer()
    }
    
    // 로컬 변경사항 표시 (간격 제한 추가)
    func markLocalChanges() {
        let now = Date()
        
        // 마지막 변경 시간과 현재 시간의 차이가 너무 적으면 무시
        if let lastChange = lastChangeTimestamp, now.timeIntervalSince(lastChange) < 1.0 {
            return
        }
        
        Task { @MainActor in
            self.hasPendingChanges = true
            self.lastChangeTimestamp = now
            
            // 자동 동기화 활성화 상태면 타이머 시작
            if self.useAutoSync {
                self.startSyncTimer()
            }
        }
    }
    
    // 자동 동기화 타이머
    private func startSyncTimer() {
        syncTimer?.invalidate()
        syncTimer = nil
        
        // 변경 후 15초 후에 동기화 시도
        syncTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            
            Task { [weak self] in
                guard let self = self else { return }
                
                // 변경사항 있는지 확인
                let hasPendingChanges = await MainActor.run { self.hasPendingChanges }
                
                // 네트워크 연결과 로그인 상태 확인
                let isConnected = NetworkMonitorService.shared.isConnected
                let isLoggedIn = AuthManager.shared.isLoggedIn
                
                // 모든 조건이 충족되는 경우에만 실행
                if hasPendingChanges && isConnected && isLoggedIn {
                    _ = await self.safeBackgroundSync()
                }
                
                // 작업 완료 후 메인 스레드에서 타이머 정리
                await MainActor.run {
                    self.syncTimer = nil
                }
            }
        }
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
    
    func setModelContext(_ context: ModelContext) {
        Task { @MainActor in
            self.modelContext = context
        }
    }
    
    // 처음 로그인 시에만 데이터 다운로드
    func performInitialSync() {
        Task {
            // 동기화 상태 확인
            let isSyncing = await MainActor.run { self.isSyncInProgress }
            if isSyncing {
                return
            }
            
            // 동기화 상태 설정
            await MainActor.run {
                self.isSyncInProgress = true
                self.isSyncing = true
                self.syncError = nil
                
                // 동기화 전략 명시적 설정
                self.syncStrategy = .localOverCloud
                self.hasConflicts = false
                self.conflictsResolved = true
            }
            
            defer {
                Task { @MainActor in
                    self.isSyncInProgress = false
                    self.isSyncing = false
                }
            }
            
            do {
                // 로컬 데이터 존재 여부 확인
                let localCharacterCount = try await MainActor.run {
                    guard let modelContext = self.modelContext else {
                        throw DataSyncError.contextNotSet
                    }
                    
                    let descriptor = FetchDescriptor<CharacterModel>()
                    return try modelContext.fetchCount(descriptor)
                }
                
                if localCharacterCount > 0 {
                    // 로컬 데이터가 있는 경우, 항상 서버에 업로드
                    let _ = await uploadToServer()
                } else {
                    // 로컬 데이터가 없는 경우에만 서버에서 다운로드
                    let cloudCharacterCount = try await countCloudCharacters()
                    
                    if cloudCharacterCount > 0 {
                        let _ = await pullFromCloud()
                    }
                }
                
                await MainActor.run {
                    AuthManager.shared.markInitialSyncComplete()
                    self.lastSyncTime = Date()
                    self.hasPendingChanges = false
                }
            } catch {
                await MainActor.run {
                    self.syncError = error
                }
            }
        }
    }
    
    // 로컬 캐릭터 개수 카운트 - 메인 액터에서 실행
    @MainActor
    private func countLocalCharacters() throws -> Int {
        guard let modelContext = self.modelContext else {
            throw DataSyncError.contextNotSet
        }
        
        let descriptor = FetchDescriptor<CharacterModel>()
        return try modelContext.fetchCount(descriptor)
    }
    
    // 오류 지우기
    func clearError() {
        Task { @MainActor in
            self.syncError = nil
        }
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
