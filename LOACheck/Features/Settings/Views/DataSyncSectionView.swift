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
        }
    }
}
