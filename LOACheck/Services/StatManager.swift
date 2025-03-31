//
//  StatManager.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 3/31/25.
//

import Foundation
import SwiftUI

class StatManager {
    static let shared = StatManager()
    
    // 부위별, 연마 레벨별 스탯 범위 (최소값, 최대값)
    private let statRanges: [String: [Int: (min: Int, max: Int)]] = [
        "반지": [
            0: (9156, 11091),
            1: (9414, 11349),
            2: (9930, 11865),
            3: (10962, 12897)
        ],
        "귀걸이": [
            0: (9861, 11944),
            1: (10139, 12222),
            2: (10695, 12778),
            3: (11806, 13889)
        ],
        "목걸이": [
            0: (12678, 15357),
            1: (13035, 15714),
            2: (13749, 16428),
            3: (15178, 17857)
        ]
    ]
    
    private init() {}
    
    // 스탯 퍼센트 계산
    func calculateStatPercentage(partType: String, upgradeLevel: Int, statValue: Int) -> Double {
        guard let ranges = statRanges[partType],
              let range = ranges[upgradeLevel] else {
            return 0.0
        }
        
        let min = range.min
        let max = range.max
        
        // 값이 범위를 벗어나는 경우 처리
        if statValue <= min { return 0.0 }
        if statValue >= max { return 100.0 }
        
        // 퍼센트 계산
        return Double(statValue - min) / Double(max - min) * 100.0
    }
    
    // 퍼센트에 따른 색상 반환
    func getColorForStatPercentage(_ percentage: Double) -> Color {
        switch percentage {
        case 0..<10: return .red
        case 10..<30: return .yellow
        case 30..<70: return .green
        case 70..<90: return .blue
        case 90..<100: return .purple
        case 100: return Color(red: 1.0, green: 0.5, blue: 0.0) // 오렌지색
        default: return .gray
        }
    }
    
    // 아이템 이름에서 부위 타입 추출
    func getPartTypeFromName(_ name: String) -> String {
        if name.contains("목걸이") { return "목걸이" }
        if name.contains("귀걸이") { return "귀걸이" }
        if name.contains("반지") { return "반지" }
        return "목걸이" // 기본값
    }
}
