//
//  ColorExtensions.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 4/7/25.
//

import SwiftUI

// MARK: - 앱 테마 색상
extension Color {
    // 로스트아크 기본 테마 색상
    static let lostarkBlue = Color(red: 0.0, green: 0.6, blue: 0.8)
    static let lostarkGold = Color(red: 1.0, green: 0.8, blue: 0.0)
    
    // 기본 시스템 색상 - 다크모드 지원
    static let dividerColor = Color("dividerColor")
    
    // 난이도별 색상
    static func difficultyColor(_ difficulty: String) -> Color {
        switch difficulty {
        case "하드":
            return .red
        case "노말":
            return .blue
        case "싱글":
            return .green
        default:
            return .gray
        }
    }
    
    // 게임 등급별 색상 - 다크모드에서도 동일한 색상 유지
    static let ancientGrade = Color(red: 0.85, green: 0.68, blue: 0.25) // 고대등급
    static let relicGrade = Color(red: 1.0, green: 0.35, blue: 0.0)    // 유물등급
    static let legendaryGrade = Color(red: 1.0, green: 0.65, blue: 0.0) // 전설등급
    static let epicGrade = Color(red: 0.5, green: 0.15, blue: 0.75)    // 영웅등급
    static let rareGrade = Color(red: 0.0, green: 0.5, blue: 1.0)      // 희귀등급
    
    // 품질 색상
    static func qualityColor(_ quality: Int) -> Color {
        switch quality {
        case 0..<10: return .red
        case 10..<30: return .yellow
        case 30..<70: return .green
        case 70..<90: return .blue
        case 90..<100: return .purple
        case 100: return Color(red: 1.0, green: 0.5, blue: 0.0)
        default: return .gray
        }
    }
    
    // 추가적인 테마 색상들
    static let goldText = Color.orange // 골드 표시용 색상
    static let successGreen = Color.green // 성공 표시용 색상
    static let errorRed = Color.red // 오류 표시용 색상
    static let warningYellow = Color.yellow // 경고 표시용 색상
}

// MARK: - 다크모드 관련 유틸리티 함수
extension Color {
    // 다크모드에서 투명도를 조정하는 헬퍼 함수
    static func dynamicOpacity(_ color: Color, light: Double, dark: Double) -> Color {
        return ThemeManager.shared.isCurrentlyInDarkMode ? color.opacity(dark) : color.opacity(light)
    }
    
    // 다크모드/라이트모드에 맞는 색상 선택
    static func dynamicColor(light: Color, dark: Color) -> Color {
        return ThemeManager.shared.isCurrentlyInDarkMode ? dark : light
    }
    
    // 자주 사용되는 동적 색상 조합
    
    // 완료 항목 배경색
    static var completedItemBackground: Color {
        return dynamicColor(
            light: Color.green.opacity(0.1),
            dark: Color.green.opacity(0.2)
        )
    }
    
    // 미완료 항목 배경색
    static var incompleteItemBackground: Color {
        return dynamicColor(
            light: Color.white,
            dark: Color.black.opacity(0.2)
        )
    }
    
    // 비활성화 항목 배경색
    static var disabledItemBackground: Color {
        return dynamicColor(
            light: Color.gray.opacity(0.05),
            dark: Color.gray.opacity(0.1)
        )
    }
    
    // 알림 배경색
    static var notificationBackground: Color {
        return dynamicColor(
            light: Color.blue.opacity(0.1),
            dark: Color.blue.opacity(0.15)
        )
    }
    
    // 경고 배경색
    static var alertBackground: Color {
        return dynamicColor(
            light: Color.yellow.opacity(0.1),
            dark: Color.yellow.opacity(0.15)
        )
    }
    
    // 오류 배경색
    static var errorAlertBackground: Color {
        return dynamicColor(
            light: Color.red.opacity(0.1),
            dark: Color.red.opacity(0.15)
        )
    }
    
    // 그림자 색상 및 불투명도
    static var shadowColor: Color {
        return dynamicColor(
            light: Color.black.opacity(0.1),
            dark: Color.black.opacity(0.3)
        )
    }
}

// MARK: - 에셋 컬러 생성 유틸리티
extension Color {
    // 다크모드 대응 색상 생성을 위한 헬퍼 함수
    static func createDarkModeColor(name: String, light: UIColor, dark: UIColor) -> String {
        return """
        {
          "colors" : [
            {
              "color" : {
                "color-space" : "display-p3",
                "components" : {
                  "alpha" : "\(light.cgColor.alpha)",
                  "blue" : "\(String(format: "0x%02X", Int(light.cgColor.components![2] * 255)))",
                  "green" : "\(String(format: "0x%02X", Int(light.cgColor.components![1] * 255)))",
                  "red" : "\(String(format: "0x%02X", Int(light.cgColor.components![0] * 255)))"
                }
              },
              "idiom" : "universal"
            },
            {
              "appearances" : [
                {
                  "appearance" : "luminosity",
                  "value" : "dark"
                }
              ],
              "color" : {
                "color-space" : "display-p3",
                "components" : {
                  "alpha" : "\(dark.cgColor.alpha)",
                  "blue" : "\(String(format: "0x%02X", Int(dark.cgColor.components![2] * 255)))",
                  "green" : "\(String(format: "0x%02X", Int(dark.cgColor.components![1] * 255)))",
                  "red" : "\(String(format: "0x%02X", Int(dark.cgColor.components![0] * 255)))"
                }
              },
              "idiom" : "universal"
            }
          ],
          "info" : {
            "author" : "xcode",
            "version" : 1
          }
        }
        """
    }
}
