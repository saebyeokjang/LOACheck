//
//  SyncSettingsView.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 4/9/25.
//

import SwiftUI
import SwiftData

/// 동기화 설정 및 상태 관리 뷰
struct SyncSettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var errorService: ErrorHandlingService
    @ObservedObject var dataSyncManager = DataSyncManager.shared
    @State private var showSyncStrategySheet = false
    @State private var showConfirmationDialog = false
    @State private var confirmationAction: (() -> Void)? = nil
    @State private var confirmationMessage = ""
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        List {
            Section(header: Text("동기화 상태")) {
                // 인증 상태
                HStack {
                    Label("계정 상태", systemImage: "person.circle")
                    Spacer()
                    Text(authManager.isLoggedIn ? "로그인됨" : "로그인 필요")
                        .foregroundColor(authManager.isLoggedIn ? .green : .orange)
                }
                
                // 동기화 상태
                if authManager.isLoggedIn {
                    HStack {
                        Label("마지막 동기화", systemImage: "arrow.triangle.2.circlepath")
                        Spacer()
                        if let lastSync = dataSyncManager.lastSyncTime {
                            Text(lastSync.formatted())
                                .foregroundColor(.secondary)
                        } else {
                            Text("동기화 없음")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack {
                        Label("상태", systemImage: "info.circle")
                        Spacer()
                        
                        if dataSyncManager.isSyncing {
                            HStack {
                                Text("동기화 중...")
                                ProgressView()
                                    .controlSize(.small)
                            }
                            .foregroundColor(.blue)
                        } else if let error = dataSyncManager.syncError {
                            Text("오류: \(error.localizedDescription)")
                                .foregroundColor(.red)
                                .lineLimit(1)
                        } else if dataSyncManager.hasPendingChanges {
                            Text("동기화 필요")
                                .foregroundColor(.orange)
                        } else {
                            Text("동기화됨")
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            
            // 동기화 방법 설정
            if authManager.isLoggedIn {
                Section(header: Text("동기화 설정")) {
                    // 동기화 전략 선택
                    HStack {
                        Label("동기화 방법", systemImage: "arrow.up.arrow.down")
                        Spacer()
                        Text(syncStrategyName(dataSyncManager.syncStrategy))
                            .foregroundColor(.blue)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showSyncStrategySheet = true
                    }
                    
                    // 자동 동기화 버튼
                    Toggle(isOn: .constant(true)) {
                        Label("자동 동기화", systemImage: "clock.arrow.2.circlepath")
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .disabled(true) // 현재 버전에서는 항상 활성화됨
                    
                    // 충돌 감지 시 경고
                    if dataSyncManager.hasConflicts && !dataSyncManager.conflictsResolved {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("데이터 충돌이 감지되었습니다")
                                .foregroundColor(.orange)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // 동기화 작업
                Section(header: Text("동기화 작업")) {
                    // 수동 동기화 버튼
                    Button(action: {
                        confirmAction(
                            message: "양방향 동기화를 실행하시겠습니까?",
                            action: performManualSync
                        )
                    }) {
                        HStack {
                            Label("양방향 동기화", systemImage: "arrow.up.arrow.down.circle")
                            Spacer()
                            if dataSyncManager.isSyncing {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                    }
                    .disabled(dataSyncManager.isSyncing || !authManager.isLoggedIn)
                    
                    // 로컬에서 클라우드로 데이터 전송
                    Button(action: {
                        confirmAction(
                            message: "로컬 데이터를 클라우드로 업로드하시겠습니까? 클라우드의 기존 데이터는 덮어쓰기됩니다.",
                            action: uploadToCloud
                        )
                    }) {
                        Label("클라우드로 업로드", systemImage: "arrow.up.circle")
                    }
                    .disabled(dataSyncManager.isSyncing || !authManager.isLoggedIn)
                    
                    // 클라우드에서 로컬로 데이터 다운로드
                    Button(action: {
                        confirmAction(
                            message: "클라우드에서 데이터를 다운로드하시겠습니까? 로컬의 기존 데이터는 덮어쓰기됩니다.",
                            action: downloadFromCloud
                        )
                    }) {
                        Label("클라우드에서 다운로드", systemImage: "arrow.down.circle")
                    }
                    .disabled(dataSyncManager.isSyncing || !authManager.isLoggedIn)
                }
                
                // 고급 설정 (주의 필요)
                Section(header: Text("고급 설정"), footer: Text("주의: 이 작업은 되돌릴 수 없습니다.")) {
                    // 로컬 데이터 초기화
                    Button(action: {
                        confirmAction(
                            message: "로컬 데이터를 모두 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.",
                            action: resetLocalData
                        )
                    }) {
                        Label("로컬 데이터 초기화", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                    
                    // 클라우드 데이터 초기화
                    Button(action: {
                        confirmAction(
                            message: "클라우드 데이터를 모두 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.",
                            action: resetCloudData
                        )
                    }) {
                        Label("클라우드 데이터 초기화", systemImage: "cloud.slash")
                            .foregroundColor(.red)
                    }
                    .disabled(!authManager.isLoggedIn)
                }
            }
        }
        .navigationTitle("동기화 설정")
        .onDisappear {
            // 뷰가 사라질 때 오류 초기화
            dataSyncManager.clearError()
        }
        .actionSheet(isPresented: $showSyncStrategySheet) {
            ActionSheet(
                title: Text("동기화 방법 선택"),
                message: Text("데이터 충돌 시 어떤 방법으로 해결할지 선택하세요"),
                buttons: [
                    .default(Text("병합 (권장)")) {
                        dataSyncManager.syncStrategy = .merge
                    },
                    .default(Text("로컬 우선")) {
                        dataSyncManager.syncStrategy = .localOverCloud
                    },
                    .default(Text("클라우드 우선")) {
                        dataSyncManager.syncStrategy = .cloudOverLocal
                    },
                    .default(Text("수동 선택")) {
                        dataSyncManager.syncStrategy = .manual
                    },
                    .cancel(Text("취소"))
                ]
            )
        }
        .alert(isPresented: $showConfirmationDialog) {
            Alert(
                title: Text("확인"),
                message: Text(confirmationMessage),
                primaryButton: .destructive(Text("확인")) {
                    confirmationAction?()
                },
                secondaryButton: .cancel()
            )
        }
    }
    
    // 동기화 전략 이름 반환
    private func syncStrategyName(_ strategy: DataSyncManager.SyncStrategy) -> String {
        switch strategy {
        case .merge:
            return "병합 (권장)"
        case .localOverCloud:
            return "로컬 우선"
        case .cloudOverLocal:
            return "클라우드 우선"
        case .manual:
            return "수동 선택"
        }
    }
    
    // 확인 대화상자 표시
    private func confirmAction(message: String, action: @escaping () -> Void) {
        confirmationMessage = message
        confirmationAction = action
        showConfirmationDialog = true
    }
    
    // 수동 동기화 수행
    private func performManualSync() {
        Task {
            let success = await dataSyncManager.performManualSync()
            
            if !success, let error = dataSyncManager.syncError {
                errorService.handleError(error, source: .sync) {
                    performManualSync()
                }
            }
        }
    }
    
    // 클라우드로 업로드
    private func uploadToCloud() {
        Task {
            let success = await dataSyncManager.pushToCloud()
            
            if !success, let error = dataSyncManager.syncError {
                errorService.handleError(error, source: .sync) {
                    uploadToCloud()
                }
            }
        }
    }
    
    // 클라우드에서 다운로드
    private func downloadFromCloud() {
        Task {
            let success = await dataSyncManager.pullFromCloud()
            
            if !success, let error = dataSyncManager.syncError {
                errorService.handleError(error, source: .sync) {
                    downloadFromCloud()
                }
            }
        }
    }
    
    // 로컬 데이터 초기화
    private func resetLocalData() {
        do {
            try modelContext.delete(model: CharacterModel.self)
            
            // 로컬 데이터를 삭제했으므로 변경 사항이 있다고 표시
            dataSyncManager.markLocalChanges()
        } catch {
            errorService.handleError(error, source: .database)
        }
    }
    
    // 클라우드 데이터 초기화
    private func resetCloudData() {
        Task {
            do {
                let repository = DataRepositoryFactory.getRepository(modelContext: modelContext)
                try await repository.deleteAllCharacters()
            } catch {
                await MainActor.run {
                    errorService.handleError(error, source: .sync)
                }
            }
        }
    }
}

// ModelContext 확장 (모델 삭제 유틸리티)
extension ModelContext {
    func delete<T: PersistentModel>(model: T.Type) throws {
        let descriptor = FetchDescriptor<T>()
        let items = try fetch(descriptor)
        for item in items {
            delete(item)
        }
    }
}
