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
    
    // 게임 등급별 색상
    static let ancientGrade = Color(red: 0.85, green: 0.68, blue: 0.25) // 고대등급
    static let relicGrade = Color(red: 1.0, green: 0.35, blue: 0.0)    // 유물등급
    static let legendaryGrade = Color(red: 1.0, green: 0.65, blue: 0.0) // 전설등급
    static let epicGrade = Color(red: 0.5, green: 0.15, blue: 0.75)    // 영웅등급
    static let rareGrade = Color(red: 0.0, green: 0.5, blue: 1.0)      // 희귀등급
}
