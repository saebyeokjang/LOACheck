//
//  NetworkMonitorService.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 4/9/25.
//

import Foundation
import Network
import Combine
import SwiftUICore

/// 네트워크 연결 상태를 모니터링하는 서비스
class NetworkMonitorService: ObservableObject {
    static let shared = NetworkMonitorService()
    
    // 연결 상태
    @Published var isConnected = true
    @Published var connectionType: ConnectionType = .unknown
    @Published var isExpensive = false // 셀룰러 등 데이터 요금 발생 연결 여부
    
    // 최근 연결 변경 시간
    private(set) var lastConnectionChangeTime = Date()
    
    // 네트워크 모니터
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    // 콜백 저장
    private var onConnect: [() -> Void] = []
    private var onDisconnect: [() -> Void] = []
    
    private init() {
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    /// 모니터링 시작
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            
            // 메인 스레드에서 상태 업데이트
            DispatchQueue.main.async {
                let oldConnected = self.isConnected
                self.isConnected = path.status == .satisfied
                
                // 연결 상태 변경 시간 업데이트
                if oldConnected != self.isConnected {
                    self.lastConnectionChangeTime = Date()
                    Logger.debug("네트워크 연결 상태 변경: \(self.isConnected ? "연결됨" : "끊김")")
                    
                    // 상태 변경에 따른 콜백 호출
                    if self.isConnected {
                        self.notifyConnectionRestored()
                    } else {
                        self.notifyConnectionLost()
                    }
                }
                
                // 연결 유형 업데이트
                if path.usesInterfaceType(.wifi) {
                    self.connectionType = .wifi
                    self.isExpensive = false
                } else if path.usesInterfaceType(.cellular) {
                    self.connectionType = .cellular
                    self.isExpensive = true
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self.connectionType = .ethernet
                    self.isExpensive = false
                } else {
                    self.connectionType = .unknown
                    self.isExpensive = true
                }
            }
        }
        
        // 모니터링 시작
        monitor.start(queue: queue)
    }
    
    /// 모니터링 중지
    func stopMonitoring() {
        monitor.cancel()
    }
    
    /// 연결 복구 시 실행할 콜백 등록
    func onConnectionRestored(_ callback: @escaping () -> Void) -> UUID {
        let id = UUID()
        onConnect.append(callback)
        return id
    }
    
    /// 연결 끊김 시 실행할 콜백 등록
    func onConnectionLost(_ callback: @escaping () -> Void) -> UUID {
        let id = UUID()
        onDisconnect.append(callback)
        return id
    }
    
    /// 연결 복구 콜백 제거
    func removeConnectionRestoredCallback(id: UUID) {
        // 실제 구현에서는 UUID로 특정 콜백을 식별하여 제거
        // 간단한 구현을 위해 생략
    }
    
    /// 연결 끊김 콜백 제거
    func removeConnectionLostCallback(id: UUID) {
        // 실제 구현에서는 UUID로 특정 콜백을 식별하여 제거
        // 간단한 구현을 위해 생략
    }
    
    /// 연결 복구 콜백 실행
    private func notifyConnectionRestored() {
        for callback in onConnect {
            callback()
        }
    }
    
    /// 연결 끊김 콜백 실행
    private func notifyConnectionLost() {
        for callback in onDisconnect {
            callback()
        }
    }
    
    /// 네트워크 상태 문자열 반환
    func getNetworkStatusString() -> String {
        if isConnected {
            let type = connectionType.displayName
            let expensive = isExpensive ? " (데이터 요금 발생)" : ""
            return "연결됨: \(type)\(expensive)"
        } else {
            return "연결 없음"
        }
    }
}

/// 연결 유형 열거형
enum ConnectionType {
    case wifi
    case cellular
    case ethernet
    case unknown
    
    var displayName: String {
        switch self {
        case .wifi:
            return "Wi-Fi"
        case .cellular:
            return "셀룰러"
        case .ethernet:
            return "유선"
        case .unknown:
            return "알 수 없음"
        }
    }
}

/// 네트워크 상태를 표시하는 뷰
struct NetworkStatusIndicatorView: View {
    @ObservedObject private var networkMonitor = NetworkMonitorService.shared
    
    var body: some View {
        HStack(spacing: 4) {
            // 상태에 따른 아이콘
            Image(systemName: networkMonitor.isConnected ?
                  (networkMonitor.connectionType == .wifi ? "wifi" : "antenna.radiowaves.left.and.right") :
                  "wifi.slash")
                .foregroundColor(networkMonitor.isConnected ? .green : .red)
                .font(.caption)
            
            // 상태 텍스트
            Text(networkMonitor.getNetworkStatusString())
                .font(.caption)
                .foregroundColor(networkMonitor.isConnected ? .secondary : .red)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

/// 오프라인 모드를 표시하는 오버레이 뷰
struct OfflineOverlayView: View {
    @ObservedObject private var networkMonitor = NetworkMonitorService.shared
    
    var body: some View {
        VStack {
            if !networkMonitor.isConnected {
                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: "wifi.slash")
                            .foregroundColor(.white)
                        
                        Text("오프라인 모드")
                            .font(.caption)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text("변경사항은 나중에 동기화됩니다")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                    .background(Color.orange)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: networkMonitor.isConnected)
    }
}
