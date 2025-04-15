//
//  DataSyncSectionView.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 4/11/25.
//

import SwiftUI

struct DataSyncSectionView: View {
    @ObservedObject var dataSyncManager: DataSyncManager
    @ObservedObject var networkMonitor: NetworkMonitorService
    @Binding var isDataSyncing: Bool
    @Binding var showSyncStrategySheet: Bool
    @Binding var alertMessage: String
    @Binding var isShowingAlert: Bool
    
    var body: some View {
        Section(header: Text("데이터 동기화")) {
            // 동기화 상태 표시
            HStack {
                Label("동기화 상태", systemImage: "arrow.triangle.2.circlepath")
                Spacer()
                
                if dataSyncManager.isSyncing {
                    HStack {
                        Text("동기화 중...")
                        ProgressView()
                            .controlSize(.small)
                    }
                    .foregroundColor(.blue)
                } else if dataSyncManager.hasPendingChanges {
                    HStack {
                        Text("동기화 필요")
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                    }
                } else {
                    Text("동기화됨")
                        .foregroundColor(.green)
                }
            }
            
            // 수동 동기화 버튼
            if dataSyncManager.hasPendingChanges || dataSyncManager.syncError != nil {
                Button(action: {
                    Task {
                        isDataSyncing = true
                        let success = await dataSyncManager.performManualSync()
                        isDataSyncing = false
                        
                        if success {
                            alertMessage = "데이터가 성공적으로 동기화되었습니다."
                        } else if let error = dataSyncManager.syncError {
                            alertMessage = "동기화 중 오류가 발생했습니다: \(error.localizedDescription)"
                        } else {
                            alertMessage = "동기화 중 오류가 발생했습니다."
                        }
                        isShowingAlert = true
                    }
                }) {
                    HStack {
                        Text("지금 동기화하기")
                        Spacer()
                        if isDataSyncing {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                }
                .disabled(isDataSyncing || !networkMonitor.isConnected)
            }
        }
    }
}
