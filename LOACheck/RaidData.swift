//
//  RaidData.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 3/21/25.
//

import Foundation

// 레이드 데이터를 관리하는 구조체
struct RaidData {
    // 레이드 타입 열거형
    enum RaidType: String, CaseIterable {
        case assaultRaid = "강습"
        case mordum = "모르둠"
        case abrelshud2 = "2막 아브렐슈드"
        case aegir = "에기르"
        case behemoth = "베히모스"
        case echidna = "에키드나"
        case kamen = "카멘"
        case ivory = "상아탑"
        case illiacan = "일리아칸"
        case kayangel = "카양겔"
        case abrelshud = "아브렐슈드"
        case clown = "쿠크세이튼"
        case vykas = "비아키스"
        case valtan = "발탄"
        case argos = "아르고스"
        
        // 레이드 정렬 우선순위
        var sortOrder: Int {
            switch self {
            case .assaultRaid: return 15
            case .mordum: return 14
            case .abrelshud2: return 13
            case .aegir: return 12
            case .behemoth: return 11
            case .echidna: return 10
            case .kamen: return 9
            case .ivory: return 8
            case .illiacan: return 7
            case .kayangel: return 6
            case .abrelshud: return 5
            case .clown: return 4
            case .vykas: return 3
            case .valtan: return 2
            case .argos: return 1
            }
        }
        
        // 각 레이드의 가능한 난이도 배열
        func difficulties() -> [Difficulty] {
            switch self {
            case .assaultRaid:
                return [.normal, .hard]
            case .mordum:
                return [.normal, .hard]
            case .abrelshud2:
                return [.normal, .hard]
            case .aegir:
                return [.normal, .hard]
            case .behemoth:
                return [.normal]
            case .echidna:
                return [.single, .normal, .hard]
            case .kamen:
                return [.single, .normal, .hard]
            case .ivory:
                return [.single, .normal, .hard]
            case .illiacan:
                return [.single, .normal, .hard]
            case .kayangel:
                return [.single, .normal, .hard]
            case .abrelshud:
                return [.single, .normal, .hard]
            case .clown:
                return [.single, .normal]
            case .vykas:
                return [.single, .normal, .hard]
            case .valtan:
                return [.single, .normal, .hard]
            case .argos:
                return [.normal]
            }
        }
        
        // 각 레이드의 관문 수
        func gateCount() -> Int {
            switch self {
            case .assaultRaid:
                return 1
            case .mordum:
                return 3
            case .abrelshud2:
                return 2
            case .aegir:
                return 2
            case .behemoth:
                return 2
            case .echidna:
                return 2
            case .kamen:
                return 4
            case .ivory:
                return 3
            case .illiacan:
                return 3
            case .kayangel:
                return 3
            case .abrelshud:
                return 4
            case .clown:
                return 3
            case .vykas:
                return 2
            case .valtan:
                return 2
            case .argos:
                return 1
            }
        }
        
        // 각 난이도에 대한 관문 수 반환
        func gateCount(for difficulty: Difficulty) -> Int {
            if self == .kamen && difficulty != .hard {
                return 3 // 카멘 싱글/노말 3관문
            }
            return gateCount()
        }
    }
    
    // 난이도 열거형
    enum Difficulty: String, CaseIterable {
        case single = "싱글"
        case normal = "노말"
        case hard = "하드"
    }
    
    // 레이드 레벨 요구사항 (최대 레벨 기준)
    static let raidLevelRequirements: [String: Double] = [
        // 강습 레이드
        "강습-노말": 1680,
        "강습-하드": 1720,
        
        // 모르둠
        "모르둠-노말": 1680,
        "모르둠-하드": 1700,
        
        // 2막 아브렐슈드
        "2막 아브렐슈드-노말": 1670,
        "2막 아브렐슈드-하드": 1690,
        
        // 에기르
        "에기르-노말": 1660,
        "에기르-하드": 1680,
        
        // 베히모스
        "베히모스-노말": 1640,
        
        // 에키드나
        "에키드나-싱글": 1620,
        "에키드나-노말": 1620,
        "에키드나-하드": 1640,
        
        // 카멘
        "카멘-싱글": 1610,
        "카멘-노말": 1610,
        "카멘-하드": 1630,
        
        // 상아탑
        "상아탑-싱글": 1600,
        "상아탑-노말": 1600,
        "상아탑-하드": 1620,
        
        // 일리아칸
        "일리아칸-싱글": 1580,
        "일리아칸-노말": 1580,
        "일리아칸-하드": 1600,
        
        // 카양겔
        "카양겔-싱글": 1540,
        "카양겔-노말": 1540,
        "카양겔-하드": 1580,
        
        // 아브렐슈드
        "아브렐슈드-싱글": 1520, // 가장 높은 관문 레벨 기준
        "아브렐슈드-노말": 1520,
        "아브렐슈드-하드": 1560, // 가장 높은 관문 레벨 기준
        
        // 쿠크세이튼
        "쿠크세이튼-싱글": 1475,
        "쿠크세이튼-노말": 1475,
        
        // 비아키스
        "비아키스-싱글": 1430,
        "비아키스-노말": 1430,
        "비아키스-하드": 1460,
        
        // 발탄
        "발탄-싱글": 1415,
        "발탄-노말": 1415,
        "발탄-하드": 1445,
        
        // 아르고스
        "아르고스-노말": 1370
    ]
    
    // 레이드 관문별 골드 보상
    static let gateGoldRewards: [String: [Int]] = [
        // 강습 레이드
        "강습-노말": [10000],
        "강습-하드": [18000],
        
        // 모르둠
        "모르둠-노말": [6000, 9500, 12500],
        "모르둠-하드": [7000, 11000, 20000],
        
        // 2막 아브렐슈드
        "2막 아브렐슈드-노말": [8500, 16500],
        "2막 아브렐슈드-하드": [10000, 20500],
        
        // 에기르
        "에기르-노말": [7500, 15500],
        "에기르-하드": [9000, 18500],
        
        // 베히모스
        "베히모스-노말": [6000, 12500],
        
        // 에키드나
        "에키드나-싱글": [4000, 7600],
        "에키드나-노말": [5000, 9500],
        "에키드나-하드": [6000, 12500],
        
        // 카멘
        "카멘-싱글": [2000, 2400, 3600],
        "카멘-노말": [2500, 3000, 4500],
        "카멘-하드": [3500, 4500, 7500, 8000],
        
        // 상아탑
        "상아탑-싱글": [1200, 1600, 2400],
        "상아탑-노말": [1500, 2000, 3000],
        "상아탑-하드": [2000, 3000, 5500],
        
        // 일리아칸
        "일리아칸-싱글": [800, 1440, 2080],
        "일리아칸-노말": [1000, 1800, 2600],
        "일리아칸-하드": [1500, 2500, 3500],
        
        // 카양겔
        "카양겔-싱글": [640, 960, 1280],
        "카양겔-노말": [800, 1200, 1600],
        "카양겔-하드": [1000, 1600, 2200],
        
        // 아브렐슈드
        "아브렐슈드-싱글": [800, 800, 800, 1280],
        "아브렐슈드-노말": [1000, 1000, 1000, 1600],
        "아브렐슈드-하드": [1200, 1200, 1200, 2000],
        
        // 쿠크세이튼
        "쿠크세이튼-싱글": [480, 720, 1200],
        "쿠크세이튼-노말": [600, 900, 1500],
        
        // 비아키스
        "비아키스-싱글": [480, 800],
        "비아키스-노말": [600, 1000],
        "비아키스-하드": [900, 1500],
        
        // 발탄
        "발탄-싱글": [400, 560],
        "발탄-노말": [500, 700],
        "발탄-하드": [700, 1100],
        
        // 아르고스
        "아르고스-노말": [1000]
    ]
    
    // 캐릭터 레벨을 기준으로 참여 가능한 레이드 목록 반환
    static func getAvailableRaids(for level: Double) -> [RaidGroup] {
        var availableRaidGroups: [RaidGroup] = []
        
        for raidType in RaidType.allCases {
            var raidDifficulties: [Difficulty] = []
            
            // 가능한 난이도 확인
            for difficulty in raidType.difficulties() {
                let key = "\(raidType.rawValue)-\(difficulty.rawValue)"
                if let requiredLevel = raidLevelRequirements[key], level >= requiredLevel {
                    raidDifficulties.append(difficulty)
                }
            }
            
            // 가능한 난이도가 있는 경우만 추가
            if !raidDifficulties.isEmpty {
                let gateCount = raidType.gateCount()
                let raidGroup = RaidGroup(
                    name: raidType.rawValue,
                    availableDifficulties: raidDifficulties,
                    gateCount: gateCount
                )
                availableRaidGroups.append(raidGroup)
            }
        }
        
        // 레벨 요구사항 기준으로 내림차순 정렬
        return availableRaidGroups.sorted { group1, group2 in
                // RaidType 찾기
                guard let type1 = RaidType.allCases.first(where: { $0.rawValue == group1.name }),
                      let type2 = RaidType.allCases.first(where: { $0.rawValue == group2.name }) else {
                    return false
                }
                
                // sortOrder 기준으로 내림차순 정렬 (높은 숫자가 먼저 나오도록)
                return type1.sortOrder > type2.sortOrder
            }
    }
    
    // 특정 레이드와 난이도의 관문별 골드 반환
    static func getGateGoldRewards(raid: String, difficulty: String) -> [Int] {
        let key = "\(raid)-\(difficulty)"
        return gateGoldRewards[key] ?? []
    }
    
    // 특정 레이드, 난이도, 관문의 골드 반환
    static func getGoldReward(raid: String, difficulty: String, gate: Int) -> Int {
        let rewards = getGateGoldRewards(raid: raid, difficulty: difficulty)
        if gate >= 0 && gate < rewards.count {
            return rewards[gate]
        }
        return 0
    }
}

// 레이드 그룹 정보 (이름, 가능한 난이도, 관문 수)
struct RaidGroup: Identifiable {
    var id: String { name }
    var name: String
    var availableDifficulties: [RaidData.Difficulty]
    var gateCount: Int
    
    // 특정 난이도에 대한 관문 수 반환
    func gateCount(for difficulty: RaidData.Difficulty) -> Int {
        if name == "카멘" && difficulty != .hard {
            return 3 // 카멘 싱글/노말은 3관문
        }
        return gateCount
    }
}
