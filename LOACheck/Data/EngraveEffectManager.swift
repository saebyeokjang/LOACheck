//
//  EngraveEffectManager.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 3/31/25.
//

import Foundation
import SwiftUICore

// MARK: - 연마효과 정보 관리자 (하드코딩 버전)
class EngraveEffectManager {
    static let shared = EngraveEffectManager()
    
    private init() {}
    
    // 각 연마효과별 코드값 매핑
    private let effectCodes: [String: Int] = [
        "추가 피해": 41,
        "적에게 주는 피해 증가": 42,
        "공격력%": 45,
        "무기 공격력%": 46,
        "치명타 적중률": 49,
        "치명타 피해": 50,
        "세레나데, 신성, 조화 게이지 획득량 증가": 43,
        "낙인력": 44,
        "파티원 회복 효과": 47,
        "파티원 보호막 효과": 48,
        "아군 공격력 강화 효과": 51,
        "아군 피해량 강화 효과": 52,
        "공격력 +": 53,
        "무기 공격력 +": 54,
        "최대 생명력": 55,
        "최대 마나": 56,
        "상태이상 공격 지속시간": 57,
        "전투 중 생명력 회복량": 58
    ]
    
    // 부위별 연마효과 맵핑
    private let categoryEffects: [AccessoryCategory: [String]] = [
        .necklace: ["추가 피해", "적에게 주는 피해 증가", "공격력 +", "무기 공격력 +"],
        .earring: ["공격력%", "무기 공격력%", "공격력 +", "무기 공격력 +"],
        .ring: ["치명타 적중률", "치명타 피해", "공격력 +", "무기 공격력 +"]
    ]
    
    // 연마효과별 가능한 값 목록
    private let effectValues: [String: [EngraveEffectValue]] = [
        "추가 피해": [
            EngraveEffectValue(displayValue: "0.60%", value: 60, isPercentage: true),
            EngraveEffectValue(displayValue: "1.60%", value: 160, isPercentage: true),
            EngraveEffectValue(displayValue: "2.60%", value: 260, isPercentage: true)
        ],
        "적에게 주는 피해 증가": [
            EngraveEffectValue(displayValue: "0.55%", value: 55, isPercentage: true),
            EngraveEffectValue(displayValue: "1.20%", value: 120, isPercentage: true),
            EngraveEffectValue(displayValue: "2.00%", value: 200, isPercentage: true)
        ],
        "공격력%": [
            EngraveEffectValue(displayValue: "0.40%", value: 40, isPercentage: true),
            EngraveEffectValue(displayValue: "0.95%", value: 95, isPercentage: true),
            EngraveEffectValue(displayValue: "1.55%", value: 155, isPercentage: true)
        ],
        "무기 공격력%": [
            EngraveEffectValue(displayValue: "0.80%", value: 80, isPercentage: true),
            EngraveEffectValue(displayValue: "1.80%", value: 180, isPercentage: true),
            EngraveEffectValue(displayValue: "3.00%", value: 300, isPercentage: true)
        ],
        "치명타 적중률": [
            EngraveEffectValue(displayValue: "0.40%", value: 40, isPercentage: true),
            EngraveEffectValue(displayValue: "0.95%", value: 95, isPercentage: true),
            EngraveEffectValue(displayValue: "1.55%", value: 155, isPercentage: true)
        ],
        "치명타 피해": [
            EngraveEffectValue(displayValue: "1.10%", value: 110, isPercentage: true),
            EngraveEffectValue(displayValue: "2.40%", value: 240, isPercentage: true),
            EngraveEffectValue(displayValue: "4.00%", value: 400, isPercentage: true)
        ],
        "공격력 +": [
            EngraveEffectValue(displayValue: "80", value: 80, isPercentage: false),
            EngraveEffectValue(displayValue: "195", value: 195, isPercentage: false),
            EngraveEffectValue(displayValue: "390", value: 390, isPercentage: false)
        ],
        "무기 공격력 +": [
            EngraveEffectValue(displayValue: "195", value: 195, isPercentage: false),
            EngraveEffectValue(displayValue: "480", value: 480, isPercentage: false),
            EngraveEffectValue(displayValue: "960", value: 960, isPercentage: false)
        ]
    ]
    
    // 연마효과 등급 판별 (하, 중, 상)
    func getEffectTier(name: String, value: Double) -> EffectTier {
        guard let values = effectValues[name] else {
            return .low
        }
        
        // isPercentage 확인
        let isPercentage = values.first?.isPercentage ?? true
        
        // 값 비교를 위한 정수값으로 변환
        let compareValue = isPercentage ? Int(value * 100) : Int(value)
        
        if values.count >= 3 {
            if compareValue <= values[0].value {
                return .low
            } else if compareValue <= values[1].value {
                return .medium
            } else {
                return .high
            }
        } else if values.count == 2 {
            if compareValue <= values[0].value {
                return .low
            } else {
                return .high
            }
        }
        
        return .low
    }

    // 연마효과 등급 열거형
    enum EffectTier {
        case low
        case medium
        case high
        
        // 등급별 색상
        var color: Color {
            switch self {
            case .low: return .blue
            case .medium: return .purple
            case .high: return Color(red: 1.0, green: 0.5, blue: 0.0) // 오렌지색
            }
        }
    }
    
    // 특정 부위에 적용 가능한 연마효과 목록 반환
    func getEngraveEffectsForCategory(_ category: AccessoryCategory) -> [String] {
        return categoryEffects[category] ?? []
    }
    
    // 연마효과의 값 목록 반환
    func getEngraveEffectValues(_ effectName: String) -> [EngraveEffectValue]? {
        return effectValues[effectName]
    }
    
    // 연마효과의 코드값 반환
    func getEngraveEffectCode(_ effectName: String) -> Int? {
        return effectCodes[effectName]
    }
    
    // isPercentage 값 반환 함수 추가
    func isPercentageEffect(_ effectName: String) -> Bool {
        return effectValues[effectName]?.first?.isPercentage ?? true
    }
}
