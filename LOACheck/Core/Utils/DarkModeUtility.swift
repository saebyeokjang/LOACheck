//
//  DarkModeUtility.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 4/21/25.
//

import SwiftUI
import Combine

// 다크모드 변경 감지 및 처리를 위한 유틸리티
class DarkModeObserver: ObservableObject {
    @Published var isDarkMode = false
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // ThemeManager의 isDarkMode 상태를 구독
        ThemeManager.shared.$isDarkMode
            .sink { [weak self] isDark in
                self?.isDarkMode = isDark
            }
            .store(in: &cancellables)
        
        // 시스템 다크모드 상태 변경 감지
        NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)
            .sink { [weak self] _ in
                self?.checkSystemDarkMode()
            }
            .store(in: &cancellables)
    }
    
    // 시스템 다크모드 확인
    private func checkSystemDarkMode() {
        let isSystemDarkMode = UITraitCollection.current.userInterfaceStyle == .dark
        // 시스템 다크모드와 앱 다크모드가 다르면 싱크
        if ThemeManager.shared.isDarkMode != isSystemDarkMode {
            // 자동 싱크 활성화한 경우 (사용자가 설정한 모드 따라가기)
            if UserDefaults.standard.bool(forKey: "autoSyncDarkMode") {
                ThemeManager.shared.isDarkMode = isSystemDarkMode
            }
        }
    }
}

// SwiftUI View 확장 - 다크모드 변경 시 애니메이션 적용
extension View {
    func darkModeCompatible() -> some View {
        self.animation(.easeInOut(duration: 0.25), value: ThemeManager.shared.isDarkMode)
    }
    
    // 다크모드에 따라 배경색 변경
    func dynamicBackground(_ lightColor: Color, _ darkColor: Color) -> some View {
        self.background(ThemeManager.shared.isDarkMode ? darkColor : lightColor)
            .animation(.easeInOut(duration: 0.25), value: ThemeManager.shared.isDarkMode)
    }
    
    // 다크모드에 따라 전경색 변경
    func dynamicForeground(_ lightColor: Color, _ darkColor: Color) -> some View {
        self.foregroundColor(ThemeManager.shared.isDarkMode ? darkColor : lightColor)
            .animation(.easeInOut(duration: 0.25), value: ThemeManager.shared.isDarkMode)
    }
}

// 사용자 정의 컬러 스키마 확장
extension ColorScheme {
    // 현재 다크모드 상태에 따라 색상 반환
    static func dynamicColor(light: Color, dark: Color) -> Color {
        ThemeManager.shared.isDarkMode ? dark : light
    }
}

// 그라데이션 다크모드 대응
extension Gradient {
    // 다크모드 대응 그라데이션
    static func dynamicGradient(
        lightColors: [Color],
        darkColors: [Color],
        startPoint: UnitPoint = .top,
        endPoint: UnitPoint = .bottom
    ) -> LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: ThemeManager.shared.isDarkMode ? darkColors : lightColors),
            startPoint: startPoint,
            endPoint: endPoint
        )
    }
}

// 상태바 스타일 설정을 위한 확장
extension UIApplication {
    // 상태바 스타일 설정
    func setStatusBarStyle(_ style: UIStatusBarStyle) {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            if let statusBarManager = windowScene.statusBarManager {
                let statusBarView = UIView(frame: statusBarManager.statusBarFrame)
                statusBarView.backgroundColor = style == .lightContent ? .black : .white
                
                if let window = windowScene.windows.first {
                    window.addSubview(statusBarView)
                }
            }
        }
    }
}

// MARK: - 뷰 수정자 (modifiers)
struct AppearanceModifier: ViewModifier {
    @ObservedObject private var themeManager = ThemeManager.shared
    
    func body(content: Content) -> some View {
        content
            .preferredColorScheme(themeManager.colorScheme)
            .animation(.easeInOut(duration: 0.25), value: themeManager.isDarkMode)
    }
}

struct ButtonStyle: ViewModifier {
    var isPrimary: Bool = true
    @Environment(\.colorScheme) private var colorScheme
    
    func body(content: Content) -> some View {
        content
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                isPrimary ? Color.blue :
                    (colorScheme == .dark ? Color.gray.opacity(0.3) : Color.gray.opacity(0.1))
            )
            .foregroundColor(isPrimary ? .white : Color.textPrimary)
            .cornerRadius(8)
            .animation(.easeInOut(duration: 0.1), value: colorScheme)
    }
}

// MARK: - View 확장 편의 메서드
extension View {
    func cardStyle() -> some View {
        self.modifier(CardStyle())
    }
    
    func buttonStyle(isPrimary: Bool = true) -> some View {
        self.modifier(ButtonStyle(isPrimary: isPrimary))
    }
    
    func withAppearance() -> some View {
        self.modifier(AppearanceModifier())
    }
}
