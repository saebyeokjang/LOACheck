//
//  RaidDataMigrationService.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 3/26/25.
//

import Foundation
import SwiftData

/// 레이드 데이터를 최신 정보로 유지하기 위한 마이그레이션 서비스
class RaidDataMigrationService {
    static let shared = RaidDataMigrationService()
    
    private init() {}
    
    // 최신 버전 정보 저장용 키
    private let lastVersionKey = "lastAppVersion"
    
    /// 앱 시작 시 호출되어 필요한 데이터 마이그레이션 수행
    @MainActor func checkAndPerformMigrations(modelContext: ModelContext) {
        // 현재 앱 버전
        let currentVersion = AppUpdateService.shared.getCurrentAppVersion()
        
        // 마지막으로 실행된 앱 버전
        let lastVersion = UserDefaults.standard.string(forKey: lastVersionKey) ?? "0.0.0"
        
        // 앱 버전 변경 감지 (첫 실행 또는 업데이트)
        let isVersionChanged = currentVersion != lastVersion
        
        if isVersionChanged {
            Logger.info("앱 버전 변경 감지: \(lastVersion) -> \(currentVersion)")
        }
        
        // 버전 변경 여부와 상관없이 항상 최신 레이드 데이터로 업데이트
        updateAllRaidData(modelContext: modelContext)
        
        // 버전이 변경되었으면 현재 버전 저장
        if isVersionChanged {
            UserDefaults.standard.set(currentVersion, forKey: lastVersionKey)
        }
    }
    
    /// 모든 캐릭터의 레이드 데이터를 최신 정보로 업데이트
    @MainActor
    private func updateAllRaidData(modelContext: ModelContext) {
        Logger.info("모든 캐릭터의 레이드 데이터 업데이트 시작")
        
        do {
            // 현재 유효한 레이드 목록 생성 (RaidData에서 가져옴)
            let validRaids = getValidRaids()
            
            // 모든 캐릭터 불러오기
            let descriptor = FetchDescriptor<CharacterModel>()
            let characters = try modelContext.fetch(descriptor)
            
            var updatedCharacters = 0
            var updatedGates = 0
            var removedGates = 0
            
            // 각 캐릭터의 레이드 게이트 업데이트
            for character in characters {
                guard let gates = character.raidGates, !gates.isEmpty else { continue }
                
                var modified = false
                
                // 삭제된 레이드 제거 및 골드 보상 업데이트
                let outdatedGates = gates.filter { gate in
                    let isValid = isValidRaidGate(gate: gate, validRaids: validRaids)
                    return !isValid
                }
                
                // 삭제된 레이드 게이트 제거
                if !outdatedGates.isEmpty {
                    for gate in outdatedGates {
                        if let index = character.raidGates?.firstIndex(where: { $0.id == gate.id }) {
                            character.raidGates?.remove(at: index)
                            removedGates += 1
                            modified = true
                        }
                    }
                }
                
                // 유효한 레이드 게이트의 골드 보상 업데이트
                let validGates = gates.filter { isValidRaidGate(gate: $0, validRaids: validRaids) }
                for gate in validGates {
                    let latestGoldReward = RaidData.getGoldReward(
                        raid: gate.raid,
                        difficulty: gate.difficulty,
                        gate: gate.gate
                    )
                    
                    // 골드 보상이 변경되었으면 업데이트
                    if gate.goldReward != latestGoldReward {
                        gate.goldReward = latestGoldReward
                        updatedGates += 1
                        modified = true
                    }
                }
                
                if modified {
                    updatedCharacters += 1
                }
            }
            
            Logger.info("레이드 데이터 업데이트 완료: \(updatedCharacters)개 캐릭터, \(updatedGates)개 게이트 업데이트, \(removedGates)개 게이트 제거")
            
        } catch {
            Logger.error("레이드 데이터 업데이트 실패", error: error)
        }
    }
    
    /// 유효한 레이드 목록 가져오기
    private func getValidRaids() -> [String: [String: Int]] {
        var validRaids: [String: [String: Int]] = [:]
        
        // RaidData의 모든 레이드 타입에 대해
        for raidType in RaidData.RaidType.allCases {
            let raidName = raidType.rawValue
            
            // 각 난이도에 대해
            for difficulty in raidType.difficulties() {
                let difficultyName = difficulty.rawValue
                
                // 관문 수 가져오기
                let gateCount = raidType.gateCount(for: difficulty)
                
                // 레이드-난이도 조합이 없으면 초기화
                if validRaids[raidName] == nil {
                    validRaids[raidName] = [:]
                }
                
                // 해당 난이도의 관문 수 저장
                validRaids[raidName]?[difficultyName] = gateCount
            }
        }
        
        return validRaids
    }
    
    /// 레이드 게이트가 유효한지 확인
    private func isValidRaidGate(gate: RaidGate, validRaids: [String: [String: Int]]) -> Bool {
        // 레이드가 존재하는지 확인
        guard let difficulties = validRaids[gate.raid] else {
            return false
        }
        
        // 난이도가 존재하는지 확인
        guard let gateCount = difficulties[gate.difficulty] else {
            return false
        }
        
        // 관문 번호가 유효한지 확인
        return gate.gate >= 0 && gate.gate < gateCount
    }
}
