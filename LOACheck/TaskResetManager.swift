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
        
        guard let todayResetTime = calendar.date(from: components) else { return }
        
        // 오늘의 리셋 시간을 지났고, 마지막 리셋이 오늘 리셋 시간 이전인 경우 리셋 실행
        if now >= todayResetTime && lastDailyReset < todayResetTime {
            resetDailyTasks(modelContext: modelContext)
            UserDefaults.standard.set(now, forKey: "lastDailyReset")
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
        
        guard let thisWeekResetTime = calendar.date(from: components) else { return }
        
        // 이번 주 수요일 06시를 지났고, 마지막 리셋이 이번 주 수요일 06시 이전인 경우 리셋 실행
        if now >= thisWeekResetTime && lastWeeklyReset < thisWeekResetTime {
            resetWeeklyRaids(modelContext: modelContext)
            UserDefaults.standard.set(now, forKey: "lastWeeklyReset")
        }
    }
    
    // 일일 숙제 리셋
    private func resetDailyTasks(modelContext: ModelContext) {
        let fetchDescriptor = FetchDescriptor<DailyTask>()
        do {
            let allDailyTasks = try modelContext.fetch(fetchDescriptor)
            for task in allDailyTasks {
                task.reset()
            }
        } catch {
            print("Failed to reset daily tasks: \(error.localizedDescription)")
        }
    }
    
    // 주간 레이드 리셋
    private func resetWeeklyRaids(modelContext: ModelContext) {
        let fetchDescriptor = FetchDescriptor<WeeklyRaid>()
        do {
            let allWeeklyRaids = try modelContext.fetch(fetchDescriptor)
            for raid in allWeeklyRaids {
                raid.reset()
            }
        } catch {
            print("Failed to reset weekly raids: \(error.localizedDescription)")
        }
    }
}
