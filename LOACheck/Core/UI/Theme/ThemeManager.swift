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
    private var isInitializing = true
    
    // 다크모드 설정
    @AppStorage("isDarkMode") var isDarkMode: Bool = false {
        didSet {
            // 초기화 중에는 변경 무시
            if isInitializing { return }
            
            // isDarkMode가 변경되면 selectedTheme도 함께 변경
            if selectedTheme != (isDarkMode ? .dark : .light) {
                selectedTheme = isDarkMode ? .dark : .light
            }
        }
    }
    
    // 선택된 테마
    @AppStorage("selectedTheme") var selectedTheme: AppTheme = .system {
        didSet {
            // 초기화 중에는 변경 무시
            if isInitializing { return }
            
            // selectedTheme이 변경되면 isDarkMode도 함께 변경
            if selectedTheme != .system {
                let newDarkMode = selectedTheme == .dark
                if isDarkMode != newDarkMode {
                    isDarkMode = newDarkMode
                }
            } else {
                // 시스템 설정을 따르는 경우
                let systemIsDark = UITraitCollection.current.userInterfaceStyle == .dark
                if isDarkMode != systemIsDark {
                    isDarkMode = systemIsDark
                }
            }
        }
    }
    init() {
        // 여기서 초기값들을 설정한 후 초기화 플래그 해제
        defer { isInitializing = false }
        
        // 초기 테마 설정 로직
        let storedTheme = UserDefaults.standard.string(forKey: "selectedTheme")
        if let themeName = storedTheme, let theme = AppTheme(rawValue: themeName) {
            self.selectedTheme = theme
            if theme != .system {
                self.isDarkMode = theme == .dark
            } else {
                // 시스템 설정 확인
                self.isDarkMode = UITraitCollection.current.userInterfaceStyle == .dark
            }
        } else {
            // 저장된 테마가 없는 경우 isDarkMode 값에 따라 설정
            self.selectedTheme = isDarkMode ? .dark : .light
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
