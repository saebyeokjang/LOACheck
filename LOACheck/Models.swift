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
        
        // 기본 일일 숙제 추가
        self.dailyTasks = [
            DailyTask(type: .eponaQuest, isCompleted: false),
            DailyTask(type: .chaosGate, isCompleted: false),
            DailyTask(type: .guardianRaid, isCompleted: false)
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
    }
    
    var type: TaskType
    var isCompleted: Bool
    var lastCompletedAt: Date?
    
    init(type: TaskType, isCompleted: Bool, lastCompletedAt: Date? = nil) {
        self.type = type
        self.isCompleted = isCompleted
        self.lastCompletedAt = lastCompletedAt
    }
    
    func reset() {
        isCompleted = false
    }
}
