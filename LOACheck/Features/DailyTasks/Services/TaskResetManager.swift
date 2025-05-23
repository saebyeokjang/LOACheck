//
//  TaskResetManager.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 3/20/25.
//

import Foundation
import SwiftData

class TaskResetManager {
    static let shared = TaskResetManager()
    
    private init() {}
    
    private let dailyResetTimeKey = "lastDailyResetTime"
    private let weeklyResetTimeKey = "lastWeeklyResetTime"
    
    // 일일/주간 리셋 시간 체크
    @MainActor
    func checkAndResetTasks(modelContext: ModelContext) {
        checkDailyReset(modelContext: modelContext)
        checkWeeklyReset(modelContext: modelContext)
        RaidDataMigrationService.shared.checkAndPerformMigrations(modelContext: modelContext)
    }
    
    // 일일 리셋 체크 (매일 06시)
    private func checkDailyReset(modelContext: ModelContext) {
        let calendar = Calendar.current
        let now = Date()
        
        // 마지막 일일 리셋 시간 가져오기
        let lastDailyReset = UserDefaults.standard.object(forKey: "lastDailyReset") as? Date ?? Date.distantPast
        
        // 오늘 06시 시간 계산
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = 6
        components.minute = 0
        components.second = 0
        
        guard let todayResetTime = calendar.date(from: components) else {
            Logger.error("일일 리셋 시간 계산 실패")
            return
        }
        
        // 오늘의 리셋 시간을 지났고, 마지막 리셋이 오늘 리셋 시간 이전인 경우
        if now >= todayResetTime && lastDailyReset < todayResetTime {
            Logger.info("일일 숙제 리셋 실행: \(todayResetTime.formatted())")
            resetDailyTasks(modelContext: modelContext)
            UserDefaults.standard.set(now, forKey: "lastDailyReset")
        }
        // 마지막 리셋 후 여러 날이 지났는지 확인
        else if lastDailyReset < todayResetTime {
            // 마지막 리셋 날짜와 오늘 사이의 일수 계산
            let daysSinceLastReset = calendar.dateComponents([.day], from: lastDailyReset, to: now).day ?? 0
            
            if daysSinceLastReset > 1 {
                Logger.info("장기간 미접속 감지: \(daysSinceLastReset)일간 접속하지 않음")
                
                // 지난 날짜만큼 휴식보너스 적립 (단, 최대 휴식보너스를 초과하지 않도록)
                applyRestingPointsForMissedDays(daysSinceLastReset, modelContext: modelContext)
                
                // 마지막 리셋 시간 업데이트
                UserDefaults.standard.set(now, forKey: "lastDailyReset")
            }
        } else {
            Logger.debug("일일 숙제 리셋 조건 미충족 - 현재: \(now.formatted()), 리셋시간: \(todayResetTime.formatted()), 마지막리셋: \(lastDailyReset.formatted())")
        }
    }
    
    // 미접속 기간 동안의 휴식보너스 적립 처리
    private func applyRestingPointsForMissedDays(_ days: Int, modelContext: ModelContext) {
        let fetchDescriptor = FetchDescriptor<DailyTask>()
        do {
            let allDailyTasks = try modelContext.fetch(fetchDescriptor)
            Logger.info("미접속 기간 휴식보너스 적립 - \(allDailyTasks.count)개 항목, \(days)일 분")
            
            for task in allDailyTasks {
                // 각 미완료 일수에 대해 휴식보너스 적립
                let incompleteCount = task.type.maxCompletionCount
                let dailyPointsToAdd = incompleteCount * task.type.pointsPerIncomplete
                
                // 최대 적립 가능한 포인트 계산 (각 컨텐츠의 최대치를 넘지 않도록)
                let maxPoints = task.type.maxRestingPoints
                let currentPoints = task.restingPoints
                let possibleAddition = maxPoints - currentPoints
                
                // 적립 가능한 만큼만 적립 (최대 휴식보너스 제한)
                let actualPointsToAdd = min(dailyPointsToAdd * days, possibleAddition)
                
                if actualPointsToAdd > 0 {
                    Logger.debug("\(task.type.rawValue): \(days)일간 미접속, 총 \(actualPointsToAdd) 휴식보너스 적립")
                    task.addRestingPoints(actualPointsToAdd)
                }
            }
        } catch {
            Logger.error("미접속 기간 휴식보너스 적립 실패", error: error)
        }
    }
    
    // 주간 리셋 체크 (매주 수요일 06시)
    private func checkWeeklyReset(modelContext: ModelContext) {
        let calendar = Calendar.current
        let now = Date()
        
        // 마지막 주간 리셋 시간 가져오기
        let lastWeeklyReset = UserDefaults.standard.object(forKey: "lastWeeklyReset") as? Date ?? Date.distantPast
        
        // 현재 주의 수요일 06시 시간 계산
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        components.weekday = 4 // 수요일
        components.hour = 6
        components.minute = 0
        components.second = 0
        
        guard let thisWeekResetTime = calendar.date(from: components) else {
            Logger.error("주간 리셋 시간 계산 실패")
            return
        }
        
        // 이번 주 수요일 06시를 지났고, 마지막 리셋이 이번 주 수요일 06시 이전인 경우 리셋 실행
        if now >= thisWeekResetTime && lastWeeklyReset < thisWeekResetTime {
            Logger.info("주간 레이드 리셋 실행: \(thisWeekResetTime.formatted())")
            resetRaidGates(modelContext: modelContext)
            UserDefaults.standard.set(now, forKey: "lastWeeklyReset")
        } else {
            Logger.debug("주간 레이드 리셋 조건 미충족 - 현재: \(now.formatted()), 리셋시간: \(thisWeekResetTime.formatted()), 마지막리셋: \(lastWeeklyReset.formatted())")
        }
    }
    
    // 일일 숙제 리셋
    private func resetDailyTasks(modelContext: ModelContext) {
        let fetchDescriptor = FetchDescriptor<DailyTask>()
        do {
            let allDailyTasks = try modelContext.fetch(fetchDescriptor)
            Logger.info("일일 숙제 리셋 - \(allDailyTasks.count)개 항목 리셋")
            
            for task in allDailyTasks {
                // 리셋 시 미완료 카운트에 따라 휴게 포인트 적립
                let incompleteCount = task.type.maxCompletionCount - task.completionCount
                
                if incompleteCount > 0 {
                    let pointsToAdd = incompleteCount * task.type.pointsPerIncomplete
                    Logger.debug("\(task.type.rawValue): 미완료 \(incompleteCount)회, 휴식보너스 \(pointsToAdd) 적립")
                    
                    // 휴게 포인트 추가
                    task.addRestingPoints(pointsToAdd)
                }
                
                // 완료 상태 초기화
                task.completionCount = 0
            }
            // 변경사항 저장
            try modelContext.save()
            DataSyncManager.shared.markLocalChanges()
            Logger.info("일일 숙제 리셋 저장 완료")
        } catch {
            Logger.error("일일 숙제 리셋 실패", error: error)
        }
    }
    
    // 주간 레이드 관문 리셋
    private func resetRaidGates(modelContext: ModelContext) {
        do {
            // 레이드 게이트 초기화
            let gateDescriptor = FetchDescriptor<RaidGate>()
            let allRaidGates = try modelContext.fetch(gateDescriptor)
            Logger.info("주간 레이드 리셋 - \(allRaidGates.count)개 관문 리셋")
            
            for gate in allRaidGates {
                gate.reset()
                // 추가골드도 확실히 초기화
                gate.additionalGold = 0
            }
            
            // 캐릭터 추가 골드 초기화
            let characterDescriptor = FetchDescriptor<CharacterModel>()
            let allCharacters = try modelContext.fetch(characterDescriptor)
            Logger.info("주간 추가 수익 리셋 - \(allCharacters.count)개 캐릭터")
            
            // 모든 캐릭터의 추가 수익 확실히 초기화
            for character in allCharacters {
                character.additionalGoldMap = "{}"
                
                // 직접 속성에도 접근하여 초기화
                var emptyMap: [String: Int] = [:]
                character.additionalGoldForRaids = emptyMap
                
                // 모든 레이드 게이트도 확실히 초기화
                if let gates = character.raidGates {
                    for gate in gates {
                        gate.additionalGold = 0
                    }
                }
            }

            // 변경사항 즉시 저장
            try modelContext.save()
            
            // 동기화 표시 및 즉시 동기화 수행
            DataSyncManager.shared.markLocalChanges()
            
            // 서버에 즉시 동기화 시도 추가 (중요)
            if AuthManager.shared.isLoggedIn && NetworkMonitorService.shared.isConnected {
                Task {
                    // 이전에는 uploadToServer를 사용했지만,
                    // 일관성을 위해 강제로 서버 데이터를 덮어쓰는 pushToCloud를 사용합니다
                    let success = await DataSyncManager.shared.pushToCloud()
                    
                    if success {
                        await MainActor.run {
                            DataSyncManager.shared.hasPendingChanges = false
                            DataSyncManager.shared.lastSyncTime = Date()
                        }
                        Logger.info("주간 레이드 리셋 데이터 서버 동기화 완료")
                    } else {
                        Logger.error("주간 레이드 리셋 데이터 서버 동기화 실패")
                        DataSyncManager.shared.markLocalChanges()
                    }
                }
            } else {
                DataSyncManager.shared.markLocalChanges()
            }
        } catch {
            Logger.error("주간 레이드 리셋 실패", error: error)
        }
    }
    
    // 앱이 백그라운드에서 돌아왔을 때 호출할 수 있는 메서드
    @MainActor
    func checkResetOnForeground(modelContext: ModelContext) {
        Logger.info("앱이 포그라운드로 돌아와 리셋 체크 시작")
        checkAndResetTasks(modelContext: modelContext)
    }
    
    // 리셋 상태 디버깅을 위한 메서드
    func logResetStatus() {
        let now = Date()
        let lastDailyReset = UserDefaults.standard.object(forKey: "lastDailyReset") as? Date
        let lastWeeklyReset = UserDefaults.standard.object(forKey: "lastWeeklyReset") as? Date
        
        Logger.info("""
        리셋 상태:
        - 현재 시간: \(now.formatted())
        - 마지막 일일 리셋: \(lastDailyReset?.formatted() ?? "없음")
        - 마지막 주간 리셋: \(lastWeeklyReset?.formatted() ?? "없음")
        """)
    }
}
