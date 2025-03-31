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
    
    // 각 연마효과별 코드값 매핑
    private let effectCodes: [String: Int] = [
        "추가 피해": 41,
        "적에게 주는 피해 증가": 42,
        "공격력 %": 45,
        "무기 공격력 %": 46,
        "치명타 적중률": 49,
        "치명타 피해": 50,
        "공격력 +": 53,
        "무기 공격력 +": 54
    ]
    
    // 부위별 연마효과 맵핑
    private let categoryEffects: [AccessoryCategory: [String]] = [
        .necklace: ["추가 피해", "적에게 주는 피해 증가", "공격력 +", "무기 공격력 +"],
        .earring: ["공격력 %", "무기 공격력 %", "공격력 +", "무기 공격력 +"],
        .ring: ["치명타 적중률", "치명타 피해", "공격력 +", "무기 공격력 +"]
    ]
    
    // 연마효과별 가능한 값 목록 - var로 변경하여 수정 가능하게 함
    private var effectValues: [String: [EngraveEffectValue]] = [
        "추가 피해": [
            EngraveEffectValue(displayValue: "0.70%", value: 70, isPercentage: true), // 0.60%에서 0.70%로 수정
            EngraveEffectValue(displayValue: "1.60%", value: 160, isPercentage: true),
            EngraveEffectValue(displayValue: "2.60%", value: 260, isPercentage: true)
        ],
        "적에게 주는 피해 증가": [
            EngraveEffectValue(displayValue: "0.55%", value: 55, isPercentage: true),
            EngraveEffectValue(displayValue: "1.20%", value: 120, isPercentage: true),
            EngraveEffectValue(displayValue: "2.00%", value: 200, isPercentage: true)
        ],
        "공격력 %": [
            EngraveEffectValue(displayValue: "0.40%", value: 40, isPercentage: true),
            EngraveEffectValue(displayValue: "0.95%", value: 95, isPercentage: true),
            EngraveEffectValue(displayValue: "1.55%", value: 155, isPercentage: true)
        ],
        "무기 공격력 %": [
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
    
    // 효과 이름 정규화를 위한 매핑
    private let effectNameMapping: [String: String] = [
        "공격력 ": "공격력",
        "무기 공격력 ": "무기 공격력",
        "세레나데 게이지 획득량 증가": "세레나데, 신성, 조화 게이지 획득량 증가",
        "신성 게이지 획득량 증가": "세레나데, 신성, 조화 게이지 획득량 증가",
        "조화 게이지 획득량 증가": "세레나데, 신성, 조화 게이지 획득량 증가"
    ]
    
    private init() {
        // 추가 효과 등록
        effectValues["파티원 보호막 효과"] = [
            EngraveEffectValue(displayValue: "0.95%", value: 95, isPercentage: true),
            EngraveEffectValue(displayValue: "2.10%", value: 210, isPercentage: true),
            EngraveEffectValue(displayValue: "3.50%", value: 350, isPercentage: true)
        ]
        
        effectValues["전투 중 생명력 회복량"] = [
            EngraveEffectValue(displayValue: "10", value: 10, isPercentage: false),
            EngraveEffectValue(displayValue: "25", value: 25, isPercentage: false),
            EngraveEffectValue(displayValue: "50", value: 50, isPercentage: false)
        ]
        
        effectValues["상태이상 공격 지속시간"] = [
            EngraveEffectValue(displayValue: "0.20%", value: 20, isPercentage: true),
            EngraveEffectValue(displayValue: "0.50%", value: 50, isPercentage: true),
            EngraveEffectValue(displayValue: "1.00%", value: 100, isPercentage: true)
        ]
        
        effectValues["파티원 회복 효과"] = [
            EngraveEffectValue(displayValue: "0.95%", value: 95, isPercentage: true),
            EngraveEffectValue(displayValue: "2.10%", value: 210, isPercentage: true),
            EngraveEffectValue(displayValue: "3.50%", value: 350, isPercentage: true)
        ]
        
        // 추가 제공된 연마효과 등록
        effectValues["낙인력"] = [
            EngraveEffectValue(displayValue: "2.15%", value: 215, isPercentage: true),
            EngraveEffectValue(displayValue: "4.80%", value: 480, isPercentage: true),
            EngraveEffectValue(displayValue: "8.00%", value: 800, isPercentage: true)
        ]
        
        effectValues["세레나데, 신성, 조화 게이지 획득량 증가"] = [
            EngraveEffectValue(displayValue: "1.60%", value: 160, isPercentage: true),
            EngraveEffectValue(displayValue: "3.60%", value: 360, isPercentage: true),
            EngraveEffectValue(displayValue: "6.00%", value: 600, isPercentage: true)
        ]
        
        effectValues["최대 마나"] = [
            EngraveEffectValue(displayValue: "6", value: 6, isPercentage: false),
            EngraveEffectValue(displayValue: "15", value: 15, isPercentage: false),
            EngraveEffectValue(displayValue: "30", value: 30, isPercentage: false)
        ]
        
        effectValues["최대 생명력"] = [
            EngraveEffectValue(displayValue: "1300", value: 1300, isPercentage: false),
            EngraveEffectValue(displayValue: "3250", value: 3250, isPercentage: false),
            EngraveEffectValue(displayValue: "6500", value: 6500, isPercentage: false)
        ]
        
        effectValues["아군 공격력 강화 효과"] = [
            EngraveEffectValue(displayValue: "1.35%", value: 135, isPercentage: true),
            EngraveEffectValue(displayValue: "3.00%", value: 300, isPercentage: true),
            EngraveEffectValue(displayValue: "5.00%", value: 500, isPercentage: true)
        ]
        
        effectValues["아군 피해량 강화 효과"] = [
            EngraveEffectValue(displayValue: "2.00%", value: 200, isPercentage: true),
            EngraveEffectValue(displayValue: "4.50%", value: 450, isPercentage: true),
            EngraveEffectValue(displayValue: "7.50%", value: 750, isPercentage: true)
        ]
        
        // 초기화시 등록된 효과 로깅
        #if DEBUG
        logAllEffectValues()
        checkEffectValueRegistration()
        #endif
    }
    
    // 연마효과 등급 판별 (하, 중, 상)
    func getEffectTier(name: String, value: Double) -> EffectTier {
        // 공백 제거 및 정규화
        var normalizedName = name.trimmingCharacters(in: .whitespaces)
        
        // 이름 매핑 적용
        if let mappedName = effectNameMapping[normalizedName] {
            normalizedName = mappedName
        }
        
        // 특수 케이스 처리
        if normalizedName == "공격력" {
            // 값으로 퍼센트인지 고정값인지 판단
            if value < 10 {
                normalizedName = "공격력 %"
            } else {
                normalizedName = "공격력 +"
            }
        }
        
        if normalizedName == "무기 공격력" {
            if value < 10 {
                normalizedName = "무기 공격력 %"
            } else {
                normalizedName = "무기 공격력 +"
            }
        }
        
        // 추가 피해 특수 케이스 - API값과 기대값 차이 수정
        if normalizedName.contains("추가 피해") {
            #if DEBUG
            Logger.debug("추가 피해 값 확인: \(value)")
            #endif
            
            // 소수점 첫째자리까지 반올림하여 정확도 향상
            let roundedValue = round(value * 10) / 10
            
            if roundedValue >= 2.6 {
                return .high
            } else if roundedValue >= 1.6 {
                return .medium
            } else {
                return .low
            }
        }
        
        // 1. 정규화된 이름으로 직접 시도
        if let values = effectValues[normalizedName] {
            return determineTier(values: values, value: value)
        }
        
        // 2. 이름의 일부로 매칭 시도 (더 유연한 검색)
        for (effectName, values) in effectValues {
            if normalizedName.contains(effectName) || effectName.contains(normalizedName) {
                #if DEBUG
                Logger.debug("효과 '\(name)'을(를) '\(effectName)'으로 매칭")
                #endif
                return determineTier(values: values, value: value)
            }
        }
        
        // 3. 특별 케이스 처리
        return determineTierResult(name: normalizedName, value: value)
    }

    // 등급 결정 로직 분리
    private func determineTier(values: [EngraveEffectValue], value: Double) -> EffectTier {
        // isPercentage 확인
        let isPercentage = values.first?.isPercentage ?? true
        
        // 값 비교를 위한 정수값으로 변환
        let compareValue = isPercentage ? Int(value * 100) : Int(value)
        
        #if DEBUG
        // 디버깅 로그
        Logger.debug("효과 등급 판정 - 원본값: \(value), 변환값: \(compareValue), isPercentage: \(isPercentage)")
        if values.count >= 3 {
            Logger.debug("  비교범위: 하옵(~\(values[0].value)), 중옵(~\(values[1].value)), 상옵(그 이상)")
        }
        #endif
        
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
    
    // 등급 판정 결과를 저장하기 위한 헬퍼 메서드
    private func determineTierResult(name: String, value: Double) -> EffectTier {
        // 공격력 특수 처리
        if name.contains("공격력") && !name.contains("무기") {
            if value >= 100 { // 고정값
                if value >= 390 {
                    return .high
                } else if value >= 195 {
                    return .medium
                } else {
                    return .low
                }
            } else { // 퍼센트
                if value >= 1.55 {
                    return .high
                } else if value >= 0.95 {
                    return .medium
                } else {
                    return .low
                }
            }
        }
        
        // 무기 공격력 특수 처리
        if name.contains("무기 공격력") {
            if value >= 100 { // 고정값
                if value >= 960 {
                    return .high
                } else if value >= 480 {
                    return .medium
                } else {
                    return .low
                }
            } else { // 퍼센트
                if value >= 3.0 {
                    return .high
                } else if value >= 1.8 {
                    return .medium
                } else {
                    return .low
                }
            }
        }
        
        // 추가 피해 특수 처리
        if name.contains("추가 피해") {
            // 반올림하여 정확도 향상
            let roundedValue = round(value * 10) / 10
            
            if roundedValue >= 2.6 {
                return .high
            } else if roundedValue >= 1.6 {
                return .medium
            } else {
                return .low
            }
        }
        
        // 낙인력
        if name.contains("낙인력") {
            if value >= 8.0 {
                return .high
            } else if value >= 4.8 {
                return .medium
            } else {
                return .low
            }
        }
        
        // 상태이상 공격 지속시간
        if name.contains("상태이상 공격 지속시간") {
            if value >= 1.0 {
                return .high
            } else if value >= 0.5 {
                return .medium
            } else {
                return .low
            }
        }
        
        // 세레나데, 신성, 조화 게이지
        if name.contains("게이지 획득량") {
            if value >= 6.0 {
                return .high
            } else if value >= 3.6 {
                return .medium
            } else {
                return .low
            }
        }
        
        // 전투 중 생명력 회복량
        if name.contains("생명력 회복") {
            if value >= 50 {
                return .high
            } else if value >= 25 {
                return .medium
            } else {
                return .low
            }
        }
        
        // 최대 마나
        if name.contains("최대 마나") {
            if value >= 30 {
                return .high
            } else if value >= 15 {
                return .medium
            } else {
                return .low
            }
        }
        
        // 최대 생명력
        if name.contains("최대 생명력") {
            if value >= 6500 {
                return .high
            } else if value >= 3250 {
                return .medium
            } else {
                return .low
            }
        }
        
        // 파티원 보호막 효과
        if name.contains("파티원 보호막") {
            if value >= 3.5 {
                return .high
            } else if value >= 2.1 {
                return .medium
            } else {
                return .low
            }
        }
        
        // 파티원 회복 효과
        if name.contains("파티원 회복") {
            if value >= 3.5 {
                return .high
            } else if value >= 2.1 {
                return .medium
            } else {
                return .low
            }
        }
        
        // 아군 공격력 강화 효과
        if name.contains("아군 공격력") {
            if value >= 5.0 {
                return .high
            } else if value >= 3.0 {
                return .medium
            } else {
                return .low
            }
        }
        
        // 아군 피해량 강화 효과
        if name.contains("아군 피해량") {
            if value >= 7.5 {
                return .high
            } else if value >= 4.5 {
                return .medium
            } else {
                return .low
            }
        }
        
        // 기본값
        Logger.debug("효과 '\(name)'에 대한 값 범위를 찾을 수 없음 - 기본값 low 반환")
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
    
    // 등록된 모든 연마효과 정보 로깅
    func logAllEffectValues() {
        Logger.debug("등록된 모든 연마효과 정보:")
        for (name, values) in effectValues {
            let valuesStr = values.map { "(\($0.displayValue): \($0.value))" }.joined(separator: ", ")
            Logger.debug("\(name): \(valuesStr)")
        }
    }

    // 앱 시작시 호출하여 등록된 연마효과 확인
    func checkEffectValueRegistration() {
        let allEffectNames = categoryEffects.values.flatMap { $0 }
        for name in allEffectNames {
            if effectValues[name] == nil {
                Logger.error("경고: '\(name)' 효과의 값 범위가 등록되지 않음")
            }
        }
    }
}
