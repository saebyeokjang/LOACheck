//
//  ErrorHandlingService.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 4/9/25.
//

import Foundation
import SwiftUI

/// 앱 전체에서 사용할 수 있는 오류 처리 서비스
class ErrorHandlingService: ObservableObject {
    static let shared = ErrorHandlingService()
    
    // 현재 오류 상태
    @Published var currentError: AppError?
    @Published var showErrorAlert = false
    
    // 오류 복구 상태
    @Published var isRecovering = false
    @Published var recoverySuccess = false
    
    private init() {}
    
    /// 오류 발생 시 호출할 메소드
    func handleError(_ error: Error, source: ErrorSource, retryAction: (() -> Void)? = nil) {
        let appError = convertToAppError(error, source: source)
        
        DispatchQueue.main.async {
            self.currentError = appError
            self.showErrorAlert = true
            
            // 자동 복구 가능한 오류인 경우 복구 시도
            if appError.isAutoRecoverable, let action = retryAction {
                self.attemptRecovery(action)
            }
            
            // 로그에 오류 기록
            self.logError(appError)
        }
    }
    
    /// 일반 오류를 앱 오류로 변환
    private func convertToAppError(_ error: Error, source: ErrorSource) -> AppError {
        // 이미 AppError면 그대로 반환
        if let appError = error as? AppError {
            return appError
        }
        
        // APIError 변환
        if let apiError = error as? APIError {
            return AppError(
                code: "API_\(apiError.localizedDescription.hashValue)",
                message: apiError.userFriendlyMessage,
                source: source,
                originalError: apiError,
                isAutoRecoverable: apiError.isAutoRecoverable,
                recoverySteps: apiError.isAutoRecoverable ? "연결 복구 중..." : "네트워크 연결을 확인하고 다시 시도하세요."
            )
        }
        
        // FirebaseError 변환
        if let firebaseError = error as? FirebaseError {
            return AppError(
                code: "FIREBASE_\(firebaseError.localizedDescription.hashValue)",
                message: firebaseError.localizedDescription,
                source: source,
                originalError: firebaseError,
                isAutoRecoverable: false,
                recoverySteps: "로그인 상태를 확인하고 다시 시도하세요."
            )
        }
        
        // DataSyncError 변환
        if let syncError = error as? DataSyncError {
            return AppError(
                code: "SYNC_\(syncError.localizedDescription.hashValue)",
                message: syncError.localizedDescription,
                source: source,
                originalError: syncError,
                isAutoRecoverable: syncError.isAutoRecoverable,
                recoverySteps: syncError.recoverySteps
            )
        }
        
        // 기타 일반 오류
        return AppError(
            code: "UNKNOWN_\(error.localizedDescription.hashValue)",
            message: error.localizedDescription,
            source: source,
            originalError: error,
            isAutoRecoverable: false,
            recoverySteps: "앱을 다시 시작해 보세요."
        )
    }
    
    /// 자동 복구 시도
    private func attemptRecovery(_ action: @escaping () -> Void) {
        DispatchQueue.main.async {
            self.isRecovering = true
        }
        
        // 지연 후 재시도
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            action()
            
            DispatchQueue.main.async {
                self.isRecovering = false
                self.recoverySuccess = true
                
                // 성공 후 상태 초기화
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.recoverySuccess = false
                    self.currentError = nil
                }
            }
        }
    }
    
    /// 오류 로깅
    private func logError(_ error: AppError) {
        Logger.error("""
        앱 오류 발생:
        - 코드: \(error.code)
        - 메시지: \(error.message)
        - 출처: \(error.source.rawValue)
        - 원본 오류: \(String(describing: error.originalError))
        - 자동 복구 가능: \(error.isAutoRecoverable)
        - 복구 단계: \(error.recoverySteps)
        """)
    }
    
    /// 오류 상태 초기화
    func clearError() {
        DispatchQueue.main.async {
            self.currentError = nil
            self.showErrorAlert = false
            self.isRecovering = false
            self.recoverySuccess = false
        }
    }
}

/// 앱 오류 구조체
struct AppError: Error, Identifiable {
    var id: String { code }
    var code: String
    var message: String
    var source: ErrorSource
    var originalError: Error?
    var isAutoRecoverable: Bool
    var recoverySteps: String
    
    init(code: String, message: String, source: ErrorSource, originalError: Error? = nil, isAutoRecoverable: Bool = false, recoverySteps: String = "") {
        self.code = code
        self.message = message
        self.source = source
        self.originalError = originalError
        self.isAutoRecoverable = isAutoRecoverable
        self.recoverySteps = recoverySteps
    }
}

/// 오류 출처 열거형
enum ErrorSource: String {
    case network = "NETWORK"
    case authentication = "AUTH"
    case database = "DATABASE"
    case sync = "SYNC"
    case api = "API"
    case ui = "UI"
    case unknown = "UNKNOWN"
}

/// APIError 확장 - 자동 복구 가능 여부
extension APIError {
    var isAutoRecoverable: Bool {
        switch self {
        case .rateLimit, .serviceUnavailable:
            return true
        default:
            return false
        }
    }
}

/// DataSyncError 확장 - 자동 복구 가능 여부 및 복구 단계
extension DataSyncError {
    var isAutoRecoverable: Bool {
        switch self {
        case .networkUnavailable:
            return true
        default:
            return false
        }
    }
    
    var recoverySteps: String {
        switch self {
        case .notAuthenticated:
            return "서비스를 이용하려면 로그인이 필요합니다."
        case .conflictDetected:
            return "동기화 방법을 선택해 주세요."
        case .networkUnavailable:
            return "네트워크 연결이 복구되면 자동으로 다시 시도합니다."
        case .contextNotSet:
            return "앱을 다시 시작해 주세요."
        case .syncFailed:
            return "설정에서 수동 동기화를 시도해 보세요."
        }
    }
}
