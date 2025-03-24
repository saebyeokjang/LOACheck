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
    
    // 일일/주간 리셋 시간 체크
    func checkAndResetTasks(modelContext: ModelContext) {
        checkDailyReset(modelContext: modelContext)
        checkWeeklyReset(modelContext: modelContext)
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
        
        // 오늘의 리셋 시간을 지났고, 마지막 리셋이 오늘 리셋 시간 이전인 경우 리셋 실행
        if now >= todayResetTime && lastDailyReset < todayResetTime {
            Logger.info("일일 숙제 리셋 실행: \(todayResetTime.formatted())")
            resetDailyTasks(modelContext: modelContext)
            UserDefaults.standard.set(now, forKey: "lastDailyReset")
        } else {
            Logger.debug("일일 숙제 리셋 조건 미충족 - 현재: \(now.formatted()), 리셋시간: \(todayResetTime.formatted()), 마지막리셋: \(lastDailyReset.formatted())")
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
        } catch {
            Logger.error("일일 숙제 리셋 실패", error: error)
        }
    }
    
    // 주간 레이드 관문 리셋
    private func resetRaidGates(modelContext: ModelContext) {
        let fetchDescriptor = FetchDescriptor<RaidGate>()
        do {
            let allRaidGates = try modelContext.fetch(fetchDescriptor)
            Logger.info("주간 레이드 리셋 - \(allRaidGates.count)개 관문 리셋")
            
            for gate in allRaidGates {
                gate.reset()
            }
        } catch {
            Logger.error("주간 레이드 리셋 실패", error: error)
        }
    }
    
    // 앱이 백그라운드에서 돌아왔을 때 호출할 수 있는 메서드
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
