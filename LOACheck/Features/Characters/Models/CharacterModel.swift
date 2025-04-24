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
            // 빈 맵 체크 강화
            guard !additionalGoldMap.isEmpty else { return [:] }
            
            // 추가 체크: 빈 객체인지 확인
            if additionalGoldMap.trimmingCharacters(in: .whitespacesAndNewlines) == "{}" {
                return [:]
            }
            
            do {
                guard let data = additionalGoldMap.data(using: .utf8) else {
                    return [:]
                }
                
                if let dict = try JSONSerialization.jsonObject(with: data) as? [String: Int] {
                    return dict
                } else {
                    // 파싱 실패 시 빈 딕셔너리 반환
                    return [:]
                }
            } catch {
                Logger.error("additionalGoldMap 파싱 실패", error: error)
                // 오류 발생 시 빈 딕셔너리 반환
                return [:]
            }
        }
        set {
            do {
                let data = try JSONSerialization.data(withJSONObject: newValue)
                if let jsonStr = String(data: data, encoding: .utf8) {
                    additionalGoldMap = jsonStr
                } else {
                    // 인코딩 실패 시 기본값 설정
                    additionalGoldMap = "{}"
                }
            } catch {
                Logger.error("additionalGoldMap 직렬화 실패", error: error)
                // 실패 시 기본값 설정
                additionalGoldMap = "{}"
            }
        }
    }
    
    @Relationship(deleteRule: .cascade, inverse: \RaidGate.character) var raidGates: [RaidGate]?
    @Relationship(deleteRule: .cascade, inverse: \DailyTask.character) var dailyTasks: [DailyTask]?
    
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
    
    private func updateRaidGatesAdditionalGold(raid: String, amount: Int) {
        guard let raidGates = self.raidGates else { return }
        
        // 해당 레이드의 모든 게이트 찾기
        let matchingGates = raidGates.filter { $0.raid == raid }
        
        // 각 게이트의 additionalGold 필드 업데이트
        for gate in matchingGates {
            gate.additionalGold = amount
            Logger.debug("레이드 게이트 additionalGold 업데이트: \(raid) - 관문 \(gate.gate + 1) - \(amount)G")
        }
    }
    
    func synchronizeAdditionalGold() {
        guard let raidGates = self.raidGates else { return }
        
        // 레이드별로 그룹화
        let groupedGates = Dictionary(grouping: raidGates) { $0.raid }
        
        for (raid, gates) in groupedGates {
            // 첫 번째 게이트의 additionalGold 값을 사용
            if let firstGate = gates.first, firstGate.additionalGold > 0 {
                // additionalGoldMap 업데이트
                setAdditionalGold(firstGate.additionalGold, for: raid)
            } else {
                // additionalGoldMap에서 값 가져와서 설정
                let amount = getAdditionalGold(for: raid)
                if amount > 0 {
                    for gate in gates {
                        gate.additionalGold = amount
                    }
                }
            }
        }
    }
    
    // 더보기 비용 계산 메서드
    func calculateBonusLootCost() -> Int {
        guard let gates = raidGates else { return 0 }
        
        return gates.filter { $0.bonusUsed }
            .reduce(0) { total, gate in
                total + RaidData.getBonusLootCost(raid: gate.raid, difficulty: gate.difficulty, gate: gate.gate)
            }
    }
    
    // 특정 레이드의 추가 수익 설정
    func setAdditionalGold(_ amount: Int, for raid: String) {
        var currentMap = additionalGoldForRaids
        currentMap[raid] = amount
        additionalGoldForRaids = currentMap
        
        // 해당 레이드의 모든 RaidGate 객체의 additionalGold도 함께 업데이트
        if let gates = self.raidGates {
            let matchingGates = gates.filter { $0.raid == raid }
            for gate in matchingGates {
                gate.additionalGold = amount
            }
        }
        do {
            let data = try JSONSerialization.data(withJSONObject: currentMap)
            if let jsonStr = String(data: data, encoding: .utf8) {
                additionalGoldMap = jsonStr
            }
        } catch {
            Logger.error("additionalGoldMap 직렬화 실패", error: error)
        }
        
        // 동기화 표시
        DataSyncManager.shared.markLocalChanges()
    }
    
    // 캐릭터에 대한 주간 골드 보상 계산 (기본 골드는 상위 3개만, 추가 수익은 모든 레이드 적용)
    func calculateWeeklyGoldReward() -> Int {
        // 우선 더보기 비용을 계산
        let bonusCost = calculateBonusLootCost()
        
        let goldReward = processRaids(onlyTopRaids: true) { raidName, gates in
            // 기본 골드 + 추가 골드
            let baseGold = gates.reduce(0) { $0 + $1.currentGoldReward }
            return baseGold + getAdditionalGold(for: raidName)
        }
        
        // 더보기 비용을 차감
        return goldReward - bonusCost
    }
    
    // 실제 획득한 골드 계산 (기본 골드는 상위 3개만, 추가 수익은 모든 레이드 적용)
    func calculateEarnedGoldReward() -> Int {
        // 우선 더보기 비용을 계산
        let bonusCost = calculateBonusLootCost()
        
        let earnedGold = processRaids(onlyTopRaids: true, onlyCompleted: true) { raidName, gates in
            // 획득한 기본 골드 + 추가 골드
            let earnedGold = gates.reduce(0) { $0 + $1.currentGoldReward }
            return earnedGold + getAdditionalGold(for: raidName)
        }
        
        // 더보기 비용을 차감
        return earnedGold - bonusCost
    }
    
    // 레이드 이름 목록 가져오기 (골드 보상 순)
    func getTopRaidNames() -> [String] {
        guard isGoldEarner, let gates = raidGates else { return [] }
        
        // 레이드별로 그룹화
        let groupedGates = Dictionary(grouping: gates) { $0.raid }
        
        let raidGolds = groupedGates.compactMap { raidName, gates -> (name: String, gold: Int)? in
            // 첫 번째 게이트가 골드 비활성화 상태인지 확인
            let isGoldDisabled = gates.first?.isGoldDisabled ?? false
            
            // 골드 비활성화된 레이드는 상위 3개에서 제외
            if isGoldDisabled {
                return nil
            }
            
            let totalGold = gates.reduce(0) { result, gate in
                return result + gate.currentGoldReward
            }
            return (name: raidName, gold: totalGold)
        }.sorted { $0.gold > $1.gold }
        
        // 상위 3개 레이드 이름 반환
        return raidGolds.prefix(3).map { $0.name }
    }
    
    // 공통 레이드 프로세싱 헬퍼 함수
    private func processRaids(
        onlyTopRaids: Bool = false,
        onlyCompleted: Bool = false,
        processor: (String, [RaidGate]) -> Int
    ) -> Int {
        guard isGoldEarner, let gates = raidGates, !gates.isEmpty else { return 0 }
        
        // 레이드별로 그룹화
        let groupedGates = Dictionary(grouping: gates) { $0.raid }
        
        // 상위 3개 레이드 이름 (필요 시)
        let topRaidNames = onlyTopRaids ? getTopRaidNames() : Array(groupedGates.keys)
        
        var totalGold = 0
        
        // 각 레이드 처리
        for (raidName, raidGates) in groupedGates {
            // 완료된 관문만 필터링 (필요 시)
            let filteredGates = onlyCompleted ? raidGates.filter { $0.isCompleted } : raidGates
            
            // 빈 게이트 배열은 건너뛰기
            if filteredGates.isEmpty && onlyCompleted {
                continue
            }
            
            // 골드 비활성화 상태 확인
            let isGoldDisabled = raidGates.first?.isGoldDisabled ?? false
            
            // 상위 레이드만 처리 (필요 시)
            if onlyTopRaids && !topRaidNames.contains(raidName) {
                // 상위 레이드가 아니면 추가 골드만 계산
                if onlyCompleted && raidGates.contains(where: { $0.isCompleted }) {
                    totalGold += getAdditionalGold(for: raidName)
                } else if !onlyCompleted {
                    totalGold += getAdditionalGold(for: raidName)
                }
                continue
            }
            
            // 골드 비활성화된 레이드는 추가 골드만 적용
            if isGoldDisabled {
                if onlyCompleted && raidGates.contains(where: { $0.isCompleted }) {
                    totalGold += getAdditionalGold(for: raidName)
                } else if !onlyCompleted {
                    totalGold += getAdditionalGold(for: raidName)
                }
                continue
            }
            
            // 커스텀 프로세서 적용
            totalGold += processor(raidName, filteredGates)
        }
        
        return totalGold
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

extension CharacterModel: @unchecked Sendable {}
