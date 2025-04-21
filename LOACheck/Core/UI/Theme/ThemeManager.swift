//
//  ThemeManager.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 4/21/25.
//

import SwiftUI

enum AppTheme: String, CaseIterable {
    case system = "시스템"
    case light = "라이트"
    case dark = "다크"
    
    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
    
    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
}

class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    // 다크모드 설정 (이전 코드와의 호환성)
    @AppStorage("isDarkMode") var isDarkMode: Bool = false {
        didSet {
            // isDarkMode가 변경되면 selectedTheme도 함께 변경
            selectedTheme = isDarkMode ? .dark : .light
        }
    }
    
    // 선택된 테마 (시스템/라이트/다크)
    @AppStorage("selectedTheme") var selectedTheme: AppTheme = .system {
        didSet {
            // selectedTheme이 변경되면 isDarkMode도 함께 변경 (이전 코드와의 호환성)
            if selectedTheme != .system {
                isDarkMode = selectedTheme == .dark
            } else {
                // 시스템 설정을 따르는 경우, 시스템 환경에 맞게 설정
                let systemIsDark = UITraitCollection.current.userInterfaceStyle == .dark
                isDarkMode = systemIsDark
            }
        }
    }
    
    // 다크모드 상태에 따른 colorScheme 반환
    var colorScheme: ColorScheme? {
        return selectedTheme == .system ? nil : (isDarkMode ? .dark : .light)
    }
    
    // 현재 테마 이름 (표시용)
    var currentThemeName: String {
        return selectedTheme.rawValue
    }
    
    // 테마 토글 함수
    func toggleTheme() {
        if selectedTheme == .dark {
            selectedTheme = .light
        } else {
            selectedTheme = .dark
        }
    }
    
    // 특정 테마로 설정
    func setTheme(_ theme: AppTheme) {
        selectedTheme = theme
    }
    
    // 현재 운영체제 다크모드 상태 반환
    func isSystemInDarkMode() -> Bool {
        return UITraitCollection.current.userInterfaceStyle == .dark
    }
    
    // 현재 실제 다크모드 상태 (시스템 설정 포함)
    var isCurrentlyInDarkMode: Bool {
        if selectedTheme == .system {
            return isSystemInDarkMode()
        }
        return isDarkMode
    }
}
