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
    
    // 인증 매니저 구독
    private var cancellables = Set<AnyCancellable>()
    private var modelContext: ModelContext?
    
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
                
                // 로컬 데이터를 클라우드로 업로드
                let repository = DataRepositoryFactory.getRepository(modelContext: modelContext)
                try await repository.syncCharactersToCloud()
                
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
            
            let repository = DataRepositoryFactory.getRepository(modelContext: modelContext)
            
            // 먼저 클라우드 데이터 가져오기
            try await repository.syncCharactersFromCloud()
            
            // 로컬 변경사항을 클라우드에 업로드
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
}

// 동기화 관련 오류 정의
enum DataSyncError: Error, LocalizedError {
    case contextNotSet
    case notAuthenticated
    case syncFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .contextNotSet:
            return "데이터 컨텍스트가 설정되지 않았습니다."
        case .notAuthenticated:
            return "동기화를 위해 로그인이 필요합니다."
        case .syncFailed(let message):
            return "동기화 실패: \(message)"
        }
    }
}
