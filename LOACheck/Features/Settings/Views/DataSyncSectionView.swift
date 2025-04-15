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
                Text("동기화 상태")
                Spacer()
                
                if dataSyncManager.isSyncing {
                    HStack {
                        Text("동기화 중...")
                        ProgressView()
                            .controlSize(.small)
                    }
                    .foregroundColor(.blue)
                } else if let lastSync = dataSyncManager.lastSyncTime {
                    Text("마지막 동기화: \(lastSync.formatted(date: .abbreviated, time: .shortened))")
                        .foregroundColor(.secondary)
                        .font(.caption)
                } else {
                    Text("아직 동기화되지 않음")
                        .foregroundColor(.secondary)
                }
            }
            
//            // 수동 동기화 버튼
//            if dataSyncManager.hasPendingChanges || dataSyncManager.syncError != nil {
//                Button(action: {
//                    Task {
//                        isDataSyncing = true
//                        let success = await dataSyncManager.performManualSync()
//                        isDataSyncing = false
//                        
//                        if success {
//                            alertMessage = "데이터가 성공적으로 동기화되었습니다."
//                        } else if let error = dataSyncManager.syncError {
//                            alertMessage = "동기화 중 오류가 발생했습니다: \(error.localizedDescription)"
//                        } else {
//                            alertMessage = "동기화 중 오류가 발생했습니다."
//                        }
//                        isShowingAlert = true
//                    }
//                }) {
//                    HStack {
//                        Text("지금 동기화하기")
//                        Spacer()
//                        if isDataSyncing {
//                            ProgressView()
//                                .controlSize(.small)
//                        }
//                    }
//                }
//                .disabled(isDataSyncing || !networkMonitor.isConnected)
//            }
        }
    }
}
