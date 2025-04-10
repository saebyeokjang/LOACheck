//
//  FriendRaidSummaryView.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 4/10/25.
//

import SwiftUI

struct FriendRaidSummaryView: View {
    var friend: Friend
    var characters: [CharacterModel]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 친구 정보 헤더
                HStack {
                    Text(friend.displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    // 골드 획득 요약
                    VStack(alignment: .trailing) {
                        Text("주간 획득 골드")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        // 기본 골드 + 추가 골드 합계
                        Text("\(totalEarnedGold) / \(totalExpectedGold) G")
                            .font(.headline)
                            .foregroundColor(.orange)
                        
                        // 기본 골드와 추가 골드 내역 표시
                        if totalBaseGold > 0 && totalAdditionalGold > 0 {
                            HStack(spacing: 2) {
                                Text("기본:")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                
                                Text("\(totalEarnedBaseGold)G")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                                
                                Text("+")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                
                                Text("추가:")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                
                                Text("\(totalEarnedAdditionalGold)G")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                
                // 캐릭터 별 레이드 정보
                ForEach(characters.sorted(by: { $0.level > $1.level })) { character in
                    CharacterRaidSummaryCard(character: character)
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("레이드 현황")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
    }
    
    // 총 예상 골드 (기본 + 추가)
    private var totalExpectedGold: Int {
        var total = 0
        
        for character in characters {
            if character.isGoldEarner {
                total += character.calculateWeeklyGoldReward()
            }
        }
        
        return total
    }
    
    // 총 획득 골드 (기본 + 추가)
    private var totalEarnedGold: Int {
        var total = 0
        
        for character in characters {
            if character.isGoldEarner {
                total += character.calculateEarnedGoldReward()
            }
        }
        
        return total
    }
    
    // 총 기본 골드 (상위 3개 레이드)
    private var totalBaseGold: Int {
        var total = 0
        
        for character in characters {
            if character.isGoldEarner, let gates = character.raidGates {
                // 레이드별로 그룹화
                let groupedGates = Dictionary(grouping: gates) { $0.raid }
                
                // 각 레이드의 골드 계산
                let raidBaseGolds = groupedGates.map { raidName, gates -> (name: String, gold: Int) in
                    let totalGold = gates.reduce(0) { $0 + $1.goldReward }
                    return (name: raidName, gold: totalGold)
                }.sorted { $0.gold > $1.gold }
                
                // 상위 3개 레이드의 기본 골드만 합산
                let topRaids = raidBaseGolds.prefix(3)
                total += topRaids.reduce(0) { $0 + $1.gold }
            }
        }
        
        return total
    }
    
    // 총 획득한 기본 골드
    private var totalEarnedBaseGold: Int {
        var total = 0
        
        for character in characters {
            if character.isGoldEarner, let gates = character.raidGates {
                // 레이드별로 그룹화
                let groupedGates = Dictionary(grouping: gates) { $0.raid }
                
                // 각 레이드의 골드 계산
                let raidGolds = groupedGates.map { raidName, gates -> (name: String, baseGold: Int, earnedBaseGold: Int) in
                    // 레이드 기본 골드
                    let totalGold = gates.reduce(0) { $0 + $1.goldReward }
                    
                    // 획득한 기본 골드 (완료된 관문만)
                    let earnedBaseGold = gates.filter { $0.isCompleted }.reduce(0) { $0 + $1.goldReward }
                    
                    return (name: raidName, baseGold: totalGold, earnedBaseGold: earnedBaseGold)
                }.sorted { $0.baseGold > $1.baseGold }
                
                // 상위 3개 레이드의 기본 획득 골드만 합산
                let topRaids = raidGolds.prefix(3)
                total += topRaids.reduce(0) { $0 + $1.earnedBaseGold }
            }
        }
        
        return total
    }
    
    // 총 추가 골드
    private var totalAdditionalGold: Int {
        var total = 0
        
        for character in characters {
            if character.isGoldEarner, let gates = character.raidGates {
                // 레이드별로 그룹화
                let groupedGates = Dictionary(grouping: gates) { $0.raid }
                let raidNames = groupedGates.keys
                
                // 모든 레이드의 추가 수익 합산
                for raidName in raidNames {
                    total += character.getAdditionalGold(for: raidName)
                }
            }
        }
        
        return total
    }
    
    // 획득한 추가 골드
    private var totalEarnedAdditionalGold: Int {
        var total = 0
        
        for character in characters {
            if character.isGoldEarner, let gates = character.raidGates {
                // 레이드별로 그룹화
                let groupedGates = Dictionary(grouping: gates) { $0.raid }
                
                // 완료된 관문이 있는 레이드의 추가 수익만 합산
                let earnedAdditionalGold = groupedGates.filter { raidName, gates in
                    // 완료된 관문이 하나라도 있는 레이드만 필터링
                    return gates.contains { $0.isCompleted }
                }.reduce(0) { result, raid in
                    // 해당 레이드의 추가 수익 합산
                    return result + character.getAdditionalGold(for: raid.key)
                }
                
                total += earnedAdditionalGold
            }
        }
        
        return total
    }
}

// 캐릭터 별 레이드 요약 카드
struct CharacterRaidSummaryCard: View {
    var character: CharacterModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 캐릭터 헤더
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(character.name)
                        .font(.headline)
                    
                    Text("\(character.server) • \(character.characterClass)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Lv. \(String(format: "%.2f", character.level))")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                }
                
                Spacer()
                
                // 골드 정보는 골드 획득 캐릭터만 표시
                if character.isGoldEarner {
                    VStack(alignment: .trailing) {
                        // 총 획득 골드 (기본 + 추가)
                        let earnedGold = character.calculateEarnedGoldReward()
                        let totalGold = character.calculateWeeklyGoldReward()
                        
                        Text("\(earnedGold) / \(totalGold) G")
                            .font(.headline)
                            .foregroundColor(.orange)
                        
                        // 골드 내역 상세 표시 (기본 + 추가)
                        if let raidGates = character.raidGates, !raidGates.isEmpty {
                            // 추가 골드 계산
                            let addGold = getAdditionalGoldSum(character)
                            
                            if addGold > 0 {
                                HStack(spacing: 2) {
                                    Text("기본:")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    
                                    Text("\(earnedGold - addGold)G")
                                        .font(.caption2)
                                        .foregroundColor(.orange)
                                    
                                    Text("+")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    
                                    Text("추가:")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    
                                    Text("\(addGold)G")
                                        .font(.caption2)
                                        .foregroundColor(.green)
                                }
                            }
                        }
                        
                        // 골드 획득 캐릭터 표시
                        Text("골드 획득")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.yellow.opacity(0.2))
                            .foregroundColor(.orange)
                            .cornerRadius(4)
                    }
                } else {
                    Text("골드 미획득")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Divider()
            
            // 레이드 정보
            if let raidGates = character.raidGates, !raidGates.isEmpty {
                // 레이드별로 그룹화
                let groupedGates = Dictionary(grouping: raidGates) { $0.raid }
                
                // 레이드 정렬 (골드 보상 기준으로 정렬)
                let topRaidNames = character.getTopRaidNames()
                let sortedRaids = groupedGates.keys.sorted { raid1, raid2 in
                    // 상위 레이드 우선
                    if topRaidNames.contains(raid1) && !topRaidNames.contains(raid2) {
                        return true
                    } else if !topRaidNames.contains(raid1) && topRaidNames.contains(raid2) {
                        return false
                    }
                    
                    // 레벨 기준 정렬 (높은 순)
                    let raid1Level = getRaidLevel(raid1)
                    let raid2Level = getRaidLevel(raid2)
                    return raid1Level > raid2Level
                }
                
                ForEach(sortedRaids, id: \.self) { raidName in
                    if let gates = groupedGates[raidName] {
                        FriendRaidRow(
                            raidName: raidName,
                            gates: gates.sorted(by: { $0.gate < $1.gate }),
                            character: character,
                            isTopRaid: topRaidNames.contains(raidName),
                            isLastRaid: raidName == sortedRaids.last
                        )
                    }
                }
            } else {
                Text("설정된 레이드가 없습니다")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    // 레이드 레벨 가져오기 (정렬용)
    private func getRaidLevel(_ raidName: String) -> Double {
        let difficulties = ["하드", "노말", "싱글"]
        
        for difficulty in difficulties {
            if let level = RaidData.raidLevelRequirements["\(raidName)-\(difficulty)"] {
                return level
            }
        }
        
        return 0.0
    }
    
    // 추가 수익 합계 계산
    private func getAdditionalGoldSum(_ character: CharacterModel) -> Int {
        guard let raidGates = character.raidGates else { return 0 }
        
        let groupedGates = Dictionary(grouping: raidGates) { $0.raid }
        
        // 완료된 관문이 있는 레이드의 추가 수익만 합산
        return groupedGates.filter { raidName, gates in
            // 완료된 관문이 하나라도 있는 레이드만 필터링
            return gates.contains { $0.isCompleted }
        }.reduce(0) { result, raid in
            // 해당 레이드의 추가 수익 합산
            return result + character.getAdditionalGold(for: raid.key)
        }
    }
}

// 레이드 행
struct FriendRaidRow: View {
    var raidName: String
    var gates: [RaidGate]
    var character: CharacterModel  // 캐릭터 정보 추가
    var isTopRaid: Bool
    var isLastRaid: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 레이드 헤더
            HStack {
                Text(raidName)
                    .font(.headline)
                    .foregroundColor(isTopRaid ? .primary : .gray)
                
                if isTopRaid {
                    Text("골드 획득")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.yellow.opacity(0.2))
                        .foregroundColor(.orange)
                        .cornerRadius(4)
                }
                
                Spacer()
                
                // 완료 현황
                let completedCount = gates.filter { $0.isCompleted }.count
                Text("\(completedCount)/\(gates.count) 완료")
                    .font(.subheadline)
                    .foregroundColor(completedCount == gates.count ? .green : .blue)
            }
            
            // 추가 수익 표시
            let additionalGold = character.getAdditionalGold(for: raidName)
            let hasCompletedGates = gates.contains { $0.isCompleted }
            
            if additionalGold > 0 {
                HStack {
                    Spacer()
                    if hasCompletedGates {
                        Text("추가 수익: +\(additionalGold)G")
                            .font(.caption)
                            .foregroundColor(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(4)
                    } else {
                        Text("예상 추가 수익: +\(additionalGold)G")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                .padding(.top, 2)
            }
            
            // 관문 그리드
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: min(gates.count, 4)),
                spacing: 8
            ) {
                ForEach(gates) { gate in
                    GateStatusCell(gate: gate)
                }
            }
        }
        .padding(.vertical, 8)
        
        if !isLastRaid {
            Divider()
        }
    }
}

// 레이드 관문 셀
struct GateStatusCell: View {
    var gate: RaidGate
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(gate.gate + 1)관문")
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundColor(gate.isCompleted ? .secondary : .primary)
                .strikethrough(gate.isCompleted)
            
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
    
    // 난이도별 색상
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
