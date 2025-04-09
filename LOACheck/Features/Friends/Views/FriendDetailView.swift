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
                                
                                Text("\(character.calculateEarnedGoldReward()) / \(character.calculateWeeklyGoldReward()) G")
                                    .font(.headline)
                                    .foregroundColor(.orange)
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
            Text(raid)
                .font(.headline)
            
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
