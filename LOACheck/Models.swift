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
    @Relationship(deleteRule: .cascade) var weeklyRaids: [WeeklyRaid]?
    
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
        
        // 캐릭터 레벨에 맞는 주간 레이드 추가
        self.weeklyRaids = []
        self.updateAvailableRaids()
    }
    
    func updateAvailableRaids() {
        // 기존 레이드 상태 저장
        var existingRaids: [String: WeeklyRaid] = [:]
        if let raids = weeklyRaids {
            for raid in raids {
                let key = "\(raid.name)-\(raid.difficulty)"
                existingRaids[key] = raid
            }
        }
        
        // 레벨에 따라 가능한 레이드 결정
        var availableRaids: [WeeklyRaid] = []
        
        // 아브렐슈드
        if level >= 1580 {
            let abyssalRaid = createOrUpdateRaid(name: "아브렐슈드", difficulty: "하드", goldReward: 4500, existingRaids: existingRaids)
            availableRaids.append(abyssalRaid)
        } else if level >= 1520 {
            let abyssalRaid = createOrUpdateRaid(name: "아브렐슈드", difficulty: "노말", goldReward: 3000, existingRaids: existingRaids)
            availableRaids.append(abyssalRaid)
        }
        
        // 카양겔
        if level >= 1580 {
            let kayangel = createOrUpdateRaid(name: "카양겔", difficulty: "하드", goldReward: 4500, existingRaids: existingRaids)
            availableRaids.append(kayangel)
        } else if level >= 1540 {
            let kayangel = createOrUpdateRaid(name: "카양겔", difficulty: "노말", goldReward: 3000, existingRaids: existingRaids)
            availableRaids.append(kayangel)
        }
        
        // 쿠크세이튼
        if level >= 1475 {
            let kouku = createOrUpdateRaid(name: "쿠크세이튼", difficulty: "하드", goldReward: 4500, existingRaids: existingRaids)
            availableRaids.append(kouku)
        } else if level >= 1445 {
            let kouku = createOrUpdateRaid(name: "쿠크세이튼", difficulty: "노말", goldReward: 3000, existingRaids: existingRaids)
            availableRaids.append(kouku)
        }
        
        // 비아키스
        if level >= 1460 {
            let vykas = createOrUpdateRaid(name: "비아키스", difficulty: "하드", goldReward: 2500, existingRaids: existingRaids)
            availableRaids.append(vykas)
        } else if level >= 1430 {
            let vykas = createOrUpdateRaid(name: "비아키스", difficulty: "노말", goldReward: 1500, existingRaids: existingRaids)
            availableRaids.append(vykas)
        }
        
        // 발탄
        if level >= 1445 {
            let valtan = createOrUpdateRaid(name: "발탄", difficulty: "하드", goldReward: 1500, existingRaids: existingRaids)
            availableRaids.append(valtan)
        } else if level >= 1415 {
            let valtan = createOrUpdateRaid(name: "발탄", difficulty: "노말", goldReward: 800, existingRaids: existingRaids)
            availableRaids.append(valtan)
        }
        
        // 아르고스
        if level >= 1370 {
            let argos = createOrUpdateRaid(name: "아르고스", difficulty: "하드", goldReward: 1600, existingRaids: existingRaids)
            availableRaids.append(argos)
        }
        
        self.weeklyRaids = availableRaids
    }
    
    private func createOrUpdateRaid(name: String, difficulty: String, goldReward: Int, existingRaids: [String: WeeklyRaid]) -> WeeklyRaid {
        let key = "\(name)-\(difficulty)"
        if let existingRaid = existingRaids[key] {
            // 기존 레이드 업데이트
            existingRaid.goldReward = goldReward
            return existingRaid
        } else {
            // 새 레이드 생성
            return WeeklyRaid(name: name, difficulty: difficulty, goldReward: goldReward, isCompleted: false)
        }
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

// MARK: - 주간 레이드 모델
@Model
final class WeeklyRaid {
    var name: String
    var difficulty: String
    var goldReward: Int
    var isCompleted: Bool
    var lastCompletedAt: Date?
    
    init(name: String, difficulty: String, goldReward: Int, isCompleted: Bool, lastCompletedAt: Date? = nil) {
        self.name = name
        self.difficulty = difficulty
        self.goldReward = goldReward
        self.isCompleted = isCompleted
        self.lastCompletedAt = lastCompletedAt
    }
    
    func reset() {
        isCompleted = false
    }
}
