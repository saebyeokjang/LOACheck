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
    static let textPrimary = Color("textPrimary")
    static let textSecondary = Color("textSecondary")
    static let cardBackground = Color("cardBackground")
    static let backgroundPrimary = Color("backgroundPrimary")
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
