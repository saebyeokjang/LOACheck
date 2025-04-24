//
//  FriendDetailView.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 4/8/25.
//

import SwiftUI
import SwiftData

struct FriendCharacterDetailView: View {
    var character: CharacterModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 캐릭터 헤더 정보
                VStack(spacing: 8) {
                    Text(character.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("\(character.server) • \(character.characterClass)")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("아이템 레벨: \(String(format: "%.2f", character.level))")
                        .font(.subheadline)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 12)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                
                // 주간 레이드 섹션만 표시
                if let raidGates = character.raidGates, !raidGates.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        // 골드 요약 정보
                        if character.isGoldEarner {
                            HStack {
                                Text("주간 획득 골드")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                
                                Spacer()
                                
                                // 더보기 비용 반영한 골드 표시
                                let bonusCost = calculateBonusCost(for: character)
                                if bonusCost > 0 {
                                    Text("\(character.calculateEarnedGoldReward() - bonusCost) / \(character.calculateWeeklyGoldReward()) G")
                                        .font(.headline)
                                        .foregroundColor(.orange)
                                } else {
                                    Text("\(character.calculateEarnedGoldReward()) / \(character.calculateWeeklyGoldReward()) G")
                                        .font(.headline)
                                        .foregroundColor(.orange)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 4)
                        }
                        
                        Text("주간 레이드")
                            .font(.headline)
                            .fontWeight(.bold)
                            .padding(.horizontal)
                        
                        Divider()
                        
                        // 레이드별로 그룹화
                        let groupedGates = Dictionary(grouping: raidGates) { $0.raid }
                        
                        ForEach(groupedGates.keys.sorted(), id: \.self) { raid in
                            if let gates = groupedGates[raid] {
                                FriendRaidView(raid: raid, gates: gates)
                                    .padding(.horizontal)
                                
                                if raid != groupedGates.keys.sorted().last {
                                    Divider()
                                        .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                    
                    // 더보기 정보 섹션 추가
                    if character.raidGates?.contains(where: { $0.bonusUsed }) == true {
                        bonusInfoSection(for: character)
                    }
                } else {
                    // 레이드 정보가 없는 경우
                    VStack {
                        Text("설정된 레이드가 없습니다")
                            .foregroundColor(.secondary)
                            .padding()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
    
    // 더보기 정보 섹션
    private func bonusInfoSection(for character: CharacterModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // 더보기 헤더
            HStack {
                Text("더보기 사용 정보")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                // 더보기 총 비용 계산
                let bonusCost = calculateBonusCost(for: character)
                Text("-\(bonusCost)G")
                    .font(.headline)
                    .foregroundColor(.orange)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            Divider()
            
            // 레이드별 더보기 정보
            let groupedGates = Dictionary(grouping: character.raidGates?.filter { $0.bonusUsed } ?? []) { $0.raid }
            
            if !groupedGates.isEmpty {
                ForEach(groupedGates.keys.sorted(), id: \.self) { raid in
                    if let gates = groupedGates[raid] {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(raid)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            HStack {
                                // 관문별 더보기 표시
                                ForEach(gates.sorted(by: { $0.gate < $1.gate })) { gate in
                                    let cost = RaidData.getBonusLootCost(
                                        raid: raid,
                                        difficulty: gate.difficulty,
                                        gate: gate.gate
                                    )
                                    
                                    VStack(spacing: 2) {
                                        Text("\(gate.gate + 1)관문")
                                            .font(.caption)
                                        
                                        Text("-\(cost)G")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.orange.opacity(0.1))
                                    .cornerRadius(6)
                                }
                                
                                Spacer()
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                        
                        if raid != groupedGates.keys.sorted().last {
                            Divider()
                                .padding(.vertical, 2)
                        }
                    }
                }
            } else {
                Text("더보기를 사용한 관문이 없습니다")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    // 더보기 비용 계산
    private func calculateBonusCost(for character: CharacterModel) -> Int {
        guard let gates = character.raidGates else { return 0 }
        
        return gates.filter { $0.bonusUsed }.reduce(0) { sum, gate in
            sum + RaidData.getBonusLootCost(
                raid: gate.raid,
                difficulty: gate.difficulty,
                gate: gate.gate
            )
        }
    }
}

// 친구 일일 숙제 행
struct FriendDailyTaskRow: View {
    var task: DailyTask
    var character: CharacterModel
    
    private var taskDisplayName: String {
        return character.getTaskDisplayName(for: task)
    }
    
    var body: some View {
        HStack {
            // 작업 이름
            Text(taskDisplayName)
                .font(.headline)
                .foregroundColor(task.completionCount == task.type.maxCompletionCount ? .secondary : .primary)
                .strikethrough(task.type == .eponaQuest ?
                           (task.completionCount == task.type.maxCompletionCount) :
                            (task.completionCount > 0))
            
            Spacer()
            
            // 휴식 게이지
            VStack(alignment: .trailing, spacing: 2) {
                // 완료 상태
                if task.type == .eponaQuest {
                    Text("\(task.completionCount)/\(task.type.maxCompletionCount)")
                        .font(.caption)
                        .foregroundColor(task.completionCount == task.type.maxCompletionCount ? .green : .gray)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(task.completionCount == task.type.maxCompletionCount ?
                                   Color.green.opacity(0.1) : Color.gray.opacity(0.1))
                        .cornerRadius(8)
                } else {
                    Text(task.completionCount > 0 ? "완료" : "미완료")
                        .font(.caption)
                        .foregroundColor(task.completionCount > 0 ? .green : .gray)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(task.completionCount > 0 ?
                                   Color.green.opacity(0.1) : Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                
                // 휴식 게이지
                HStack(spacing: 4) {
                    // 휴식 아이콘
                    Image(systemName: "bed.double.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.blue)
                    
                    // 휴식 포인트
                    Text("\(task.restingPoints)/\(task.type.maxRestingPoints)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// 친구 레이드 뷰
struct FriendRaidView: View {
    var raid: String
    var gates: [RaidGate]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 레이드 이름
            HStack {
                Text(raid)
                    .font(.headline)
                
                // 더보기 사용 정보 추가
                let bonusCount = gates.filter { $0.bonusUsed }.count
                if bonusCount > 0 {
                    Text("(더보기: \(bonusCount)회)")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            
            // 관문 그리드
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: min(gates.count, 4)),
                spacing: 8
            ) {
                ForEach(gates.sorted(by: { $0.gate < $1.gate })) { gate in
                    FriendRaidGateView(gate: gate)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

// 친구 레이드 관문 뷰
struct FriendRaidGateView: View {
    var gate: RaidGate
    
    var body: some View {
        VStack(spacing: 4) {
            // 관문 번호와 난이도
            Text("\(gate.gate + 1)관문")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(gate.isCompleted ? .secondary : .primary)
                .strikethrough(gate.isCompleted)
            
            // 난이도
            Text(gate.difficulty)
                .font(.caption2)
                .foregroundColor(getDifficultyColor(gate.difficulty))
                .strikethrough(gate.isCompleted)
            
            // 완료 상태
            Image(systemName: gate.isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundColor(gate.isCompleted ? .green : .gray)
                .font(.system(size: 14))
            
            // 더보기 표시 추가
            if gate.bonusUsed {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 10))
            }
        }
        .frame(height: 60)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
        .background(gate.isCompleted ? Color.green.opacity(0.1) : Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
    
    // 난이도에 따른 색상 반환
    private func getDifficultyColor(_ difficulty: String) -> Color {
        switch difficulty {
        case "하드":
            return .red
        case "노말":
            return .blue
        case "싱글":
            return .green
        default:
            return .gray
        }
    }
}
