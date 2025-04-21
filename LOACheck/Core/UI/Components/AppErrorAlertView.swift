//
//  AppErrorAlertView.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 4/9/25.
//

import SwiftUI

struct AppErrorAlertView: View {
    @EnvironmentObject var errorService: ErrorHandlingService
    var retryAction: (() -> Void)?
    
    var body: some View {
        VStack {
            if let error = errorService.currentError {
                if errorService.showErrorAlert {
                    AlertOverlay(
                        title: getErrorTitle(from: error.source),
                        message: error.message,
                        recoverySteps: error.recoverySteps,
                        isRecovering: errorService.isRecovering,
                        recoverySuccess: errorService.recoverySuccess,
                        primaryButtonTitle: error.isAutoRecoverable ? "자동 복구 중..." : "확인",
                        secondaryButtonTitle: retryAction != nil ? "다시 시도" : nil,
                        primaryAction: {
                            errorService.clearError()
                        },
                        secondaryAction: retryAction
                    )
                }
            }
        }
    }
    
    private func getErrorTitle(from source: ErrorSource) -> String {
        switch source {
        case .network:
            return "네트워크 오류"
        case .authentication:
            return "인증 오류"
        case .database:
            return "데이터 오류"
        case .sync:
            return "동기화 오류"
        case .api:
            return "API 오류"
        case .ui:
            return "화면 표시 오류"
        case .unknown:
            return "오류 발생"
        }
    }
}

/// 알림 오버레이 뷰
struct AlertOverlay: View {
    var title: String
    var message: String
    var recoverySteps: String
    var isRecovering: Bool
    var recoverySuccess: Bool
    var primaryButtonTitle: String
    var secondaryButtonTitle: String?
    var primaryAction: () -> Void
    var secondaryAction: (() -> Void)?
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack {
            // 배경 블러 효과
            Color.black.opacity(colorScheme == .dark ? 0.6 : 0.4)
                .edgesIgnoringSafeArea(.all)
            
            // 알림 카드
            VStack(spacing: 16) {
                // 제목
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .padding(.top)
                
                // 메시지
                Text(message)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // 복구 단계
                if !recoverySteps.isEmpty {
                    Text(recoverySteps)
                        .font(.caption)
                        .foregroundColor(.blue)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // 복구 상태 인디케이터
                if isRecovering {
                    ProgressView()
                        .padding()
                } else if recoverySuccess {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.green)
                        .padding()
                }
                
                // 버튼
                HStack(spacing: 16) {
                    // 기본 버튼
                    Button(action: primaryAction) {
                        Text(primaryButtonTitle)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .disabled(isRecovering)
                    
                    // 보조 버튼 (있는 경우)
                    if let secondaryTitle = secondaryButtonTitle, let secondaryAction = secondaryAction {
                        Button(action: secondaryAction) {
                            Text(secondaryTitle)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.gray.opacity(0.2))
                                .foregroundColor(.primary)
                                .cornerRadius(8)
                        }
                        .disabled(isRecovering)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .background(Color(.cardBackground))
            .cornerRadius(16)
            .padding(.horizontal, 32)
            .shadow(radius: 20)
        }
    }
}
