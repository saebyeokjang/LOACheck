//
//  CharacterModel.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 3/31/25.
//

import Foundation
import SwiftData
import SwiftUI

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
    var additionalGoldMap: String = "{}"
    
    @Transient
    var additionalGoldForRaids: [String: Int] {
        get {
            guard let data = additionalGoldMap.data(using: .utf8),
                  let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Int] else {
                return [:]
            }
            return dict
        }
        set {
            if let data = try? JSONSerialization.data(withJSONObject: newValue),
               let jsonStr = String(data: data, encoding: .utf8) {
                additionalGoldMap = jsonStr
            }
        }
    }
    
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
    
    // 특정 레이드의 추가 수익 가져오기
    func getAdditionalGold(for raid: String) -> Int {
        return additionalGoldForRaids[raid] ?? 0
    }
    
    // 특정 레이드의 추가 수익 설정
    func setAdditionalGold(_ amount: Int, for raid: String) {
        var currentMap = additionalGoldForRaids
        currentMap[raid] = amount
        additionalGoldForRaids = currentMap
    }
    
    // 캐릭터에 대한 주간 골드 보상 계산 (최대 3개 레이드만 적용)
    func calculateWeeklyGoldReward() -> Int {
        guard isGoldEarner, let gates = raidGates else { return 0 }
        
        // 레이드별로 그룹화
        let groupedGates = Dictionary(grouping: gates) { $0.raid }
        
        // 각 레이드의 총 골드 계산 (기본 + 추가)
        let raidGolds = groupedGates.map { raidName, gates -> (name: String, gold: Int) in
            let baseGold = gates.reduce(0) { result, gate in
                return result + gate.currentGoldReward
            }
            let additionalGold = getAdditionalGold(for: raidName)
            return (name: raidName, gold: baseGold + additionalGold)
        }.sorted { $0.gold > $1.gold }
        
        // 상위 3개 레이드의 골드만 합산
        let topRaids = raidGolds.prefix(3)
        let totalGold = topRaids.reduce(0) { result, raid in
            return result + raid.gold
        }
        
        return totalGold
    }
    
    // 실제 획득한 골드 계산
    func calculateEarnedGoldReward() -> Int {
        guard isGoldEarner, let gates = raidGates else { return 0 }
        
        // 레이드별로 그룹화
        let groupedGates = Dictionary(grouping: gates) { $0.raid }
        
        // 각 레이드의 골드 계산
        let raidGolds = groupedGates.map { raidName, gates -> (name: String, gold: Int, earnedGold: Int) in
            // 레이드 기본 골드
            let totalGold = gates.reduce(0) { result, gate in
                return result + gate.currentGoldReward
            }
            
            // 획득한 기본 골드 (완료된 관문만)
            let earnedBaseGold = gates.filter { $0.isCompleted }.reduce(0) { result, gate in
                return result + gate.currentGoldReward
            }
            
            // 추가 골드 (컨텐츠가 하나라도 완료되었을 때만 적용)
            let additionalGold = earnedBaseGold > 0 ? getAdditionalGold(for: raidName) : 0
            
            return (name: raidName, gold: totalGold + additionalGold, earnedGold: earnedBaseGold + additionalGold)
        }.sorted { $0.gold > $1.gold }
        
        // 상위 3개 레이드의 획득 골드만 합산
        let topRaids = raidGolds.prefix(3)
        let earnedGold = topRaids.reduce(0) { result, raid in
            return result + raid.earnedGold
        }
        
        return earnedGold
    }
    
    // 레이드 이름 목록 가져오기 (골드 보상 순)
    func getTopRaidNames() -> [String] {
        guard isGoldEarner, let gates = raidGates else { return [] }
        
        // 레이드별로 그룹화
        let groupedGates = Dictionary(grouping: gates) { $0.raid }
        
        // 각 레이드의 총 골드 계산 (currentGoldReward 사용)
        let raidGolds = groupedGates.map { raidName, gates -> (name: String, gold: Int) in
            let totalGold = gates.reduce(0) { result, gate in
                return result + gate.currentGoldReward
            }
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
    
    // 일일 숙제 이름을 레벨에 따라 반환
    func getTaskDisplayName(for task: DailyTask) -> String {
        return task.type.displayName(for: self.level)
    }
    
    // TaskType을 직접 받는 버전도 추가
    func getTaskDisplayName(for taskType: DailyTask.TaskType) -> String {
        return taskType.displayName(for: self.level)
    }
}
