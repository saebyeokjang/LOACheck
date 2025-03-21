//
//  RaidGateModels.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 3/21/25.
//

import Foundation
import SwiftData

// 관문별 레이드 설정을 위한 모델
@Model
final class RaidGate {
    var raid: String  // 레이드 이름 (ex: "모르둠")
    var gate: Int     // 관문 번호 (0부터 시작)
    var difficulty: String  // 난이도 (ex: "노말", "하드")
    var goldReward: Int     // 골드 보상
    var isCompleted: Bool   // 완료 여부
    var lastCompletedAt: Date?
    
    var displayName: String {
        "\(raid) \(gate + 1)관문(\(difficulty))"
    }
    
    init(raid: String, gate: Int, difficulty: String, goldReward: Int, isCompleted: Bool = false, lastCompletedAt: Date? = nil) {
        self.raid = raid
        self.gate = gate
        self.difficulty = difficulty
        self.goldReward = goldReward
        self.isCompleted = isCompleted
        self.lastCompletedAt = lastCompletedAt
    }
    
    func reset() {
        isCompleted = false
    }
}

// 사용자에게 표시할 레이드 게이트 정보
struct RaidGateInfo: Identifiable, Equatable {
    var id: String { "\(raid)-\(gate)-\(difficulty)" }
    var raid: String  // 레이드 이름
    var gate: Int     // 관문 번호 (0부터 시작)
    var difficulty: String  // 난이도
    var goldReward: Int     // 골드 보상
    
    var displayName: String {
        "\(gate + 1)관문(\(difficulty))"
    }
    
    static func == (lhs: RaidGateInfo, rhs: RaidGateInfo) -> Bool {
        return lhs.id == rhs.id
    }
}
