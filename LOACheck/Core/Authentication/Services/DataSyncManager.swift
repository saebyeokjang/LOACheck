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
    @Published var useAutoSync: Bool = true
    
    // 동기화 상태
    @Published var isSyncing = false
    @Published var lastSyncTime: Date?
    @Published var syncError: Error?
    @Published var hasPendingChanges = false
    
    // 충돌 감지 관련 속성 추가
    @Published var hasConflicts = false
    @Published var conflictsResolved = false
    
    // 인증 매니저 구독
    private var cancellables = Set<AnyCancellable>()
    var modelContext: ModelContext?
    
    // 동기화 전략 선택 (단순화를 위해 보존만 함)
    enum SyncStrategy {
        case localOverCloud  // 로컬 데이터 우선
        case cloudOverLocal  // 클라우드 데이터 우선
        case merge           // 데이터 병합 (최신 데이터 기준)
        case manual          // 수동 선택
    }
    
    @Published var syncStrategy: SyncStrategy = .merge
    
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
    
    // 충돌 감지 메소드 추가
    func detectConflicts() -> Bool {
        guard let modelContext = self.modelContext else {
            return false
        }
        
        do {
            // 로컬 데이터가 있는지 확인
            let descriptor = FetchDescriptor<CharacterModel>()
            let localCharactersCount = try modelContext.fetchCount(descriptor)
            
            if localCharactersCount == 0 {
                // 로컬 데이터가 없으면 충돌 없음
                return false
            }
            
            // 동기화 전략이 수동이면 항상 충돌로 판단
            if syncStrategy == .manual {
                return true
            }
            
            // 네트워크 연결 확인
            if !NetworkMonitorService.shared.isConnected {
                return false
            }
            return false
        } catch {
            Logger.error("충돌 감지 중 오류 발생", error: error)
            return false
        }
    }
    
    private func checkForConflicts() async -> Bool {
        guard let modelContext = self.modelContext else {
            return false
        }
        
        do {
            // 로컬 데이터 확인
            let descriptor = FetchDescriptor<CharacterModel>()
            let localCharactersCount = try modelContext.fetchCount(descriptor)
            
            if localCharactersCount == 0 {
                // 로컬 데이터가 없으면 충돌 없음
                return false
            }
            
            // 동기화 전략이 수동이 아니면 충돌 감지 생략
            if syncStrategy != .manual {
                return false
            }
            
            // 서버 데이터 확인
            let cloudCharactersCount = try await countCloudCharacters()
            
            // 양쪽 모두 데이터가 있으면 충돌 가능성 있음
            if localCharactersCount > 0 && cloudCharactersCount > 0 {
                await MainActor.run {
                    self.hasConflicts = true
                    self.conflictsResolved = false
                }
                return true
            }
            
            return false
        } catch {
            Logger.error("비동기 충돌 감지 중 오류 발생", error: error)
            return false
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
    
    // ModelContext 설정
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    // 백그라운드에서 안전하게 동기화를 실행하는 메소드
    func safeBackgroundSync() async {
        // 로그인 상태 및 변경사항 있는 경우에만 실행
        if AuthManager.shared.isLoggedIn && hasPendingChanges && NetworkMonitorService.shared.isConnected {
            _ = await uploadToServer()
        }
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
                    // 로컬 데이터가 있는 경우, 서버에 업로드
                    try await uploadToServer()
                } else {
                    // 로컬 데이터가 없는 경우, 서버에서 데이터 확인
                    let cloudCharacterCount = try await countCloudCharacters()
                    
                    if cloudCharacterCount > 0 {
                        // 서버에 데이터가 있으면 다운로드
                        try await recoverFromServer()
                    } else {
                        // 양쪽 모두 데이터가 없는 경우
                        Logger.info("초기 데이터가 없습니다. 동기화 완료.")
                    }
                }
                
                // 초기 동기화 완료 표시
                AuthManager.shared.markInitialSyncComplete()
                
                lastSyncTime = Date()
                isSyncing = false
                hasPendingChanges = false
            } catch {
                syncError = error
                isSyncing = false
            }
        }
    }
    
    /// 백그라운드용 안전한 동기화 메소드 - 로컬에서 서버로 업로드만 수행
    func uploadToServer() async -> Bool {
        guard let modelContext = self.modelContext else {
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
        
        // 이미 동기화 중이면 무시
        if isSyncing {
            return false
        }
        
        // 충돌 감지 검사 추가
        if await checkForConflicts() {
            // 충돌이 해결되지 않았으면 동기화 중단
            if !conflictsResolved {
                await MainActor.run {
                    self.syncError = DataSyncError.conflictDetected
                }
                return false
            }
        }
        
        do {
            await MainActor.run {
                self.isSyncing = true
                self.syncError = nil
            }
            
            // 로컬 캐릭터 가져오기
            let descriptor = FetchDescriptor<CharacterModel>()
            let localCharacters = try modelContext.fetch(descriptor)
            
            if !localCharacters.isEmpty {
                // 서버에 업로드 - 기존 캐릭터 삭제 없이 업데이트만 수행
                try await FirebaseRepository.shared.saveCharacters(localCharacters)
                
                await MainActor.run {
                    self.lastSyncTime = Date()
                    self.isSyncing = false
                    self.hasPendingChanges = false
                    self.hasConflicts = false  // 동기화 성공 시 충돌 상태 초기화
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
    
    /// 서버에서 데이터 복구 (사용자가 수동으로 호출)
    func recoverFromServer() async -> Bool {
        guard let modelContext = self.modelContext else {
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
            
            // 서버에서 캐릭터 가져오기
            let serverCharacters = try await FirebaseRepository.shared.fetchCharacters()
            
            if !serverCharacters.isEmpty {
                // 기존 로컬 데이터 삭제
                let descriptor = FetchDescriptor<CharacterModel>()
                let localCharacters = try modelContext.fetch(descriptor)
                
                for character in localCharacters {
                    modelContext.delete(character)
                }
                
                // 서버 데이터 저장
                for character in serverCharacters {
                    modelContext.insert(character)
                }
                
                try modelContext.save()
                
                await MainActor.run {
                    self.lastSyncTime = Date()
                    self.isSyncing = false
                    self.hasPendingChanges = false
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
    
    // 이전 메소드 호환성 유지 (performManualSync -> uploadToServer 호출)
    func performManualSync() async -> Bool {
        return await uploadToServer()
    }
    
    // 다음 메소드 호환성 유지 (pushToCloud -> uploadToServer 호출)
    func pushToCloud() async -> Bool {
        return await uploadToServer()
    }
    
    // 다음 메소드 호환성 유지 (pullFromCloud -> recoverFromServer 호출)
    func pullFromCloud() async -> Bool {
        return await recoverFromServer()
    }
    
    // 로컬 변경사항 표시
    func markLocalChanges() {
        let now = Date()
        
        DispatchQueue.main.async {
            self.hasPendingChanges = true
            self.lastChangeTimestamp = now
            
            // 자동 동기화 활성화 상태면 타이머 시작
            if self.useAutoSync {
                self.startSyncTimer()
            }
        }
    }
    
    // 자동 동기화 타이머 시작 메서드
    private func startSyncTimer() {
        // 이미 타이머가 실행 중이면 무시
        if syncTimer != nil {
            return
        }
        
        // 변경 후 15초 후에 동기화 시도
        syncTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            
            Task {
                // 네트워크 연결 확인
                if self.hasPendingChanges && NetworkMonitorService.shared.isConnected && AuthManager.shared.isLoggedIn {
                    _ = await self.uploadToServer()
                }
                
                // 타이머 정리
                self.syncTimer = nil
            }
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
