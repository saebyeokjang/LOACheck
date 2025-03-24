//
//  Models.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 3/20/25.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - 캐릭터 모델
@Model
final class CharacterModel {
    var name: String
    var server: String
    var characterClass: String
    var level: Double
    var imageURL: String?
    var isHidden: Bool
    var isGoldEarner: Bool
    var lastUpdated: Date
    
    @Relationship(deleteRule: .cascade) var dailyTasks: [DailyTask]?
    @Relationship(deleteRule: .cascade) var raidGates: [RaidGate]?  // 관문별 레이드로 변경
    
    init(
        name: String,
        server: String,
        characterClass: String,
        level: Double,
        imageURL: String? = nil,
        isHidden: Bool = false,
        isGoldEarner: Bool = false
    ) {
        self.name = name
        self.server = server
        self.characterClass = characterClass
        self.level = level
        self.imageURL = imageURL
        self.isHidden = isHidden
        self.isGoldEarner = isGoldEarner
        self.lastUpdated = Date()
        
        // 기본 일일 숙제 추가 - isCompleted 대신 completionCount 사용
        self.dailyTasks = [
            DailyTask(type: .eponaQuest, completionCount: 0),
            DailyTask(type: .chaosGate, completionCount: 0),
            DailyTask(type: .guardianRaid, completionCount: 0)
        ]
        
        // 레이드 관문은 빈 배열로 초기화 (사용자가 직접 설정)
        self.raidGates = []
    }
    
    // 캐릭터에 대한 주간 골드 보상 계산 (최대 3개 레이드만 적용)
    func calculateWeeklyGoldReward() -> Int {
        guard isGoldEarner, let gates = raidGates else { return 0 }
        
        // 레이드별로 그룹화
        let groupedGates = Dictionary(grouping: gates) { $0.raid }
        
        // 각 레이드의 총 골드 계산
        let raidGolds = groupedGates.map { raidName, gates -> (name: String, gold: Int) in
            let totalGold = gates.reduce(0) { $0 + $1.goldReward }
            return (name: raidName, gold: totalGold)
        }.sorted { $0.gold > $1.gold }
        
        // 상위 3개 레이드의 골드만 합산
        let topRaids = raidGolds.prefix(3)
        let totalGold = topRaids.reduce(0) { $0 + $1.gold }
        
        return totalGold
    }
    
    // 실제 획득한 골드 계산
    func calculateEarnedGoldReward() -> Int {
        guard isGoldEarner, let gates = raidGates else { return 0 }
        
        // 레이드별로 그룹화
        let groupedGates = Dictionary(grouping: gates) { $0.raid }
        
        // 각 레이드의 총 골드 계산
        let raidGolds = groupedGates.map { raidName, gates -> (name: String, gold: Int, earnedGold: Int) in
            let totalGold = gates.reduce(0) { $0 + $1.goldReward }
            let earnedGold = gates.filter { $0.isCompleted }.reduce(0) { $0 + $1.goldReward }
            return (name: raidName, gold: totalGold, earnedGold: earnedGold)
        }.sorted { $0.gold > $1.gold }
        
        // 상위 3개 레이드의 획득 골드만 합산
        let topRaids = raidGolds.prefix(3)
        let earnedGold = topRaids.reduce(0) { $0 + $1.earnedGold }
        
        return earnedGold
    }
    
    // 레이드 이름 목록 가져오기 (골드 보상 순)
    func getTopRaidNames() -> [String] {
        guard isGoldEarner, let gates = raidGates else { return [] }
        
        // 레이드별로 그룹화
        let groupedGates = Dictionary(grouping: gates) { $0.raid }
        
        // 각 레이드의 총 골드 계산
        let raidGolds = groupedGates.map { raidName, gates -> (name: String, gold: Int) in
            let totalGold = gates.reduce(0) { $0 + $1.goldReward }
            return (name: raidName, gold: totalGold)
        }.sorted { $0.gold > $1.gold }
        
        // 상위 3개 레이드 이름 반환
        return raidGolds.prefix(3).map { $0.name }
    }
    
    // 레벨에 맞는 참가 가능한 레이드 목록 반환
    func getAvailableRaidGroups() -> [RaidGroup] {
        return RaidData.getAvailableRaids(for: level)
    }
    
    // 레이드별 설정된 관문 정보 가져오기
    func getRaidGatesGrouped() -> [String: [RaidGate]] {
        guard let gates = raidGates else { return [:] }
        return Dictionary(grouping: gates) { $0.raid }
    }
}

// MARK: - 일일 숙제 모델
@Model
final class DailyTask {
    enum TaskType: String, Codable {
        case eponaQuest = "에포나 의뢰"
        case chaosGate = "쿠르잔 전선"
        case guardianRaid = "가디언 토벌"
        
        // 각 컨텐츠별 휴게 포인트 설정
        var maxRestingPoints: Int {
            switch self {
            case .eponaQuest: return 100
            case .chaosGate: return 200
            case .guardianRaid: return 100
            }
        }
        
        // 미완료 시 획득하는 휴게 포인트
        var pointsPerIncomplete: Int {
            switch self {
            case .eponaQuest: return 10 // 1회당 10포인트
            case .chaosGate: return 20
            case .guardianRaid: return 10
            }
        }
        
        // 콘텐츠 완료 시 소모되는 휴게 포인트
        var pointsPerCompletion: Int {
            switch self {
            case .eponaQuest: return 20 // 1회당 20포인트 소모
            case .chaosGate: return 40
            case .guardianRaid: return 20
            }
        }
        
        // 최대 일일 완료 횟수
        var maxCompletionCount: Int {
            switch self {
            case .eponaQuest: return 3
            case .chaosGate: return 1
            case .guardianRaid: return 1
            }
        }
    }
    
    var type: TaskType
    var completionCount: Int = 0 // 완료 횟수
    var lastCompletedAt: Date?
    var restingPoints: Int = 0 // 휴게 포인트
    
    // 각 단계별 사용된 휴게 포인트 저장 (배열 대신 개별 속성으로)
    var usedRestingPoint1: Int = 0
    var usedRestingPoint2: Int = 0
    var usedRestingPoint3: Int = 0
    
    // 배열 접근을 위한 계산 속성 (SwiftData에 저장되지 않음)
    @Transient
    var usedRestingPoints: [Int] {
        get {
            return [usedRestingPoint1, usedRestingPoint2, usedRestingPoint3]
        }
        set {
            if newValue.count > 0 { usedRestingPoint1 = newValue[0] }
            if newValue.count > 1 { usedRestingPoint2 = newValue[1] }
            if newValue.count > 2 { usedRestingPoint3 = newValue[2] }
        }
    }
    
    // 기존 isCompleted 대신 completionCount를 사용하되, 이전 코드와의 호환성을 위한 계산 프로퍼티
    var isCompleted: Bool {
        get {
            return completionCount >= type.maxCompletionCount
        }
        set {
            completionCount = newValue ? type.maxCompletionCount : 0
        }
    }
    
    init(type: TaskType, completionCount: Int = 0, lastCompletedAt: Date? = nil, restingPoints: Int = 0) {
        self.type = type
        self.completionCount = completionCount
        self.lastCompletedAt = lastCompletedAt
        self.restingPoints = restingPoints
        
        // 개별 속성 초기화
        self.usedRestingPoint1 = 0
        self.usedRestingPoint2 = 0
        self.usedRestingPoint3 = 0
    }
    
    func reset() {
        // 리셋 시 미완료 상태였다면 휴게 포인트 추가
        let incompleteCount = type.maxCompletionCount - completionCount
        if incompleteCount > 0 {
            let pointsToAdd = incompleteCount * type.pointsPerIncomplete
            addRestingPoints(pointsToAdd)
        }
        completionCount = 0
        
        // 사용된 휴게 포인트 기록 초기화
        usedRestingPoint1 = 0
        usedRestingPoint2 = 0
        usedRestingPoint3 = 0
    }
    
    // 휴게 포인트 추가 (최대값 제한)
    func addRestingPoints(_ points: Int) {
        restingPoints = min(restingPoints + points, type.maxRestingPoints)
    }
    
    // 콘텐츠 완료 시 휴게 포인트 소모 (단계 지정)
    func consumeRestingPoints(forStep step: Int) -> Bool {
        if restingPoints >= type.pointsPerCompletion {
            restingPoints -= type.pointsPerCompletion
            
            // 해당 단계에 사용된 포인트 기록
            switch step {
            case 0: usedRestingPoint1 = type.pointsPerCompletion
            case 1: usedRestingPoint2 = type.pointsPerCompletion
            case 2: usedRestingPoint3 = type.pointsPerCompletion
            default: break
            }
            
            return true // 소모 성공
        }
        
        // 해당 단계 소모 실패 시 0으로 기록
        switch step {
        case 0: usedRestingPoint1 = 0
        case 1: usedRestingPoint2 = 0
        case 2: usedRestingPoint3 = 0
        default: break
        }
        
        return false // 소모 실패 (포인트 부족)
    }
    
    // 간편 버전 - 현재 completionCount에 해당하는 단계 사용
    func consumeRestingPoints() -> Bool {
        return consumeRestingPoints(forStep: completionCount)
    }
    
    // 완료 취소 시 휴게 포인트 반환
    func returnRestingPoints(forStep step: Int) {
        var pointsToReturn = 0
        
        switch step {
        case 0:
            pointsToReturn = usedRestingPoint1
            usedRestingPoint1 = 0
        case 1:
            pointsToReturn = usedRestingPoint2
            usedRestingPoint2 = 0
        case 2:
            pointsToReturn = usedRestingPoint3
            usedRestingPoint3 = 0
        default:
            return
        }
        
        if pointsToReturn > 0 {
            addRestingPoints(pointsToReturn)
        }
    }
    
    // 휴게 포인트 비율 계산 (프로그레스 바용)
    var restingPointsRatio: Double {
        guard type.maxRestingPoints > 0 else { return 0 }
        return Double(restingPoints) / Double(type.maxRestingPoints)
    }
}
