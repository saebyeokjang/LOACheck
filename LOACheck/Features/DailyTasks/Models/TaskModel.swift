//
//  TaskModel.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 3/31/25.
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class DailyTask {
    enum TaskType: String, Codable {
        case eponaQuest = "에포나 의뢰"
        case chaosGate = "쿠르잔 전선"
        case guardianRaid = "가디언 토벌"
        
        // 캐릭터 레벨에 따른 컨텐츠 이름 반환 (새로 추가)
        func displayName(for level: Double) -> String {
            switch self {
            case .chaosGate:
                return level >= 1640 ? "쿠르잔 전선" : "카오스 던전"
            default:
                return rawValue
            }
        }
        
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
    
    @Relationship var character: CharacterModel?
    
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
