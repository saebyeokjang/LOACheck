//
//  AppInfoSectionView.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 4/11/25.
//

import SwiftUI

struct AppInfoSectionView: View {
    var networkMonitor: NetworkMonitorService
    var errorService: ErrorHandlingService
    @Binding var alertMessage: String
    @Binding var isShowingAlert: Bool
    @State private var isRefreshing = false
    @State private var showUpdateAlert = false
    @State private var latestVersion = ""
    @State private var releaseNotes: String? = nil
    @AppStorage("skipVersion") private var skipVersion = ""
    
    var body: some View {
        Section(header: Text("앱 정보")) {
            HStack {
                Text("앱 버전")
                Spacer()
                Text(AppUpdateService.shared.getCurrentAppVersion())
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("리셋 시간")
                Spacer()
                VStack(alignment: .trailing) {
                    Text("일일: 매일 06:00")
                    Text("주간: 매주 수요일 06:00")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Button(action: checkForUpdates) {
                HStack {
                    Text("업데이트 확인")
                    if isRefreshing {
                        Spacer()
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
            .disabled(isRefreshing || !networkMonitor.isConnected)
        }
        .alert("업데이트 확인", isPresented: $showUpdateAlert) {
            Button("업데이트") {
                openAppStore()
            }
            Button("나중에", role: .cancel) { }
            Button("이 버전 건너뛰기", role: .destructive) {
                skipVersion = latestVersion
            }
        } message: {
            Text(releaseNotes != nil ? "v\(latestVersion) 업데이트가 있습니다.\n\n\(releaseNotes!)" : "v\(latestVersion) 업데이트가 있습니다.")
        }
    }
    
    // 업데이트 확인
    private func checkForUpdates() {
        guard networkMonitor.isConnected else {
            alertMessage = "오프라인 상태에서는 업데이트를 확인할 수 없습니다."
            isShowingAlert = true
            return
        }
        
        isRefreshing = true
        
        Task {
            // 현재 버전
            let currentVersion = AppUpdateService.shared.getCurrentAppVersion()
            
            // 최신 버전 정보 가져오기
            let result = await AppUpdateService.shared.checkForUpdate()
            
            await MainActor.run {
                isRefreshing = false
                
                switch result {
                case .success(let versionInfo):
                    latestVersion = versionInfo.latestVersion
                    releaseNotes = versionInfo.releaseNotes
                    
                    // 업데이트 필요성 확인
                    let updateAvailable = AppUpdateService.shared.isUpdateAvailable(
                        currentVersion: currentVersion,
                        latestVersion: latestVersion
                    )
                    
                    if updateAvailable {
                        // 사용자가 이 버전을 건너뛰기로 했는지 확인
                        if latestVersion != skipVersion {
                            showUpdateAlert = true
                        } else {
                            // 사용자가 이미 이 버전을 건너뛰기로 했음
                            alertMessage = "새 버전(v\(latestVersion))이 있지만 건너뛰기로 설정되었습니다."
                            isShowingAlert = true
                        }
                    } else {
                        alertMessage = "현재 최신 버전을 사용 중입니다. (v\(currentVersion))"
                        isShowingAlert = true
                    }
                    
                case .failure(let error):
                    errorService.handleError(error, source: .network) {
                        // 재시도 액션
                        checkForUpdates()
                    }
                    alertMessage = "업데이트 확인 중 오류가 발생했습니다: \(error.localizedDescription)"
                    isShowingAlert = true
                }
            }
        }
    }
    
    // 앱스토어 열기
    private func openAppStore() {
        if let url = URL(string: "itms-apps://itunes.apple.com/app/id\(AppUpdateService.appID)") {
            UIApplication.shared.open(url)
        }
    }
}
