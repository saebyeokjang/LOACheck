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
        List {
            GoldSummaryHeader(totalGold: totalExpectedGold, earnedGold: totalEarnedGold, bonusCost: totalBonusCost)
            
            // 캐릭터별 골드 내역 섹션
            Section(header: Text("캐릭터별 골드 내역")) {
                if characters.isEmpty {
                    EmptyGoldEarnersView()
                } else {
                    ForEach(characters.sorted(by: { $0.level > $1.level })) { character in
                        FriendCharacterGoldRow(character: character)
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("\(friend.displayName)의 레이드 현황")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // 총 더보기 비용 계산
    private var totalBonusCost: Int {
        var total = 0
        
        for character in characters {
            if character.isGoldEarner {
                total += character.calculateBonusLootCost()
            }
        }
        
        return total
    }
    
    // 총 예상 골드
    private var totalExpectedGold: Int {
        var total = 0
        
        for character in characters {
            if character.isGoldEarner {
                total += character.calculateWeeklyGoldReward()
            }
        }
        
        return total
    }
    
    // 총 획득 골드
    private var totalEarnedGold: Int {
        var total = 0
        
        for character in characters {
            if character.isGoldEarner {
                total += character.calculateEarnedGoldReward()
            }
        }
        
        return total
    }
}

struct FriendCharacterGoldRow: View {
    var character: CharacterModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 캐릭터 기본 정보
            HStack {
                Text(character.name)
                    .font(.headline)
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    if character.isGoldEarner {
                        Text("\(character.calculateEarnedGoldReward()) / \(character.calculateWeeklyGoldReward()) G")
                            .font(.headline)
                            .foregroundColor(.orange)
                    } else {
                        Text("골드 미획득")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            
            Text("\(character.server) • \(character.characterClass) • Lv.\(String(format: "%.0f", character.level))")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // 레이드별 골드 내역
            if let gates = character.raidGates, !gates.isEmpty {
                Divider()
                    .padding(.vertical, 4)
                
                // 레이드별로 그룹화
                let groupedGates = Dictionary(grouping: gates) { $0.raid }
                
                // 상위 3개 레이드 이름 (골드 높은 순 기준)
                let topRaidNames = character.getTopRaidNames()
                
                // RaidType.sortOrder 기준으로 내림차순 정렬
                let sortedRaidNames = groupedGates.keys.sorted { raid1, raid2 in
                    // RaidType 찾기
                    guard let type1 = RaidData.RaidType.allCases.first(where: { $0.rawValue == raid1 }),
                          let type2 = RaidData.RaidType.allCases.first(where: { $0.rawValue == raid2 }) else {
                        return raid1 < raid2 // 기본 알파벳 순
                    }
                    
                    // sortOrder 기준으로 내림차순 정렬 (높은 숫자가 먼저 나오도록)
                    return type1.sortOrder > type2.sortOrder
                }
                
                // 레이드별 정보 표시 - 정렬된 순서대로
                ForEach(sortedRaidNames, id: \.self) { raidName in
                    if let raidGates = groupedGates[raidName] {
                        FriendRaidInfoRow(
                            character: character,
                            raidName: raidName,
                            raidGates: raidGates,
                            isTopRaid: topRaidNames.contains(raidName),
                            isLastRaid: raidName == sortedRaidNames.last
                        )
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// 레이드 정보 행
struct FriendRaidInfoRow: View {
    let character: CharacterModel
    let raidName: String
    let raidGates: [RaidGate]
    let isTopRaid: Bool
    let isLastRaid: Bool
    
    // 계산 변수들
    private var isGoldDisabled: Bool {
        return raidGates.first?.isGoldDisabled ?? false
    }
    
    private var totalGold: Int {
        return raidGates.reduce(0) { $0 + $1.currentGoldReward }
    }
    
    private var earnedGold: Int {
        return raidGates.filter { $0.isCompleted }.reduce(0) { $0 + $1.currentGoldReward }
    }
    
    private var additionalGold: Int {
        return character.getAdditionalGold(for: raidName)
    }
    
    private var displayAdditionalGold: Int {
        return hasCompletedGates ? additionalGold : 0
    }
    
    private var hasCompletedGates: Bool {
        return raidGates.contains { $0.isCompleted }
    }
    
    // 더보기 사용 관문 수와 비용
    private var bonusGatesCount: Int {
        return raidGates.filter { $0.bonusUsed }.count
    }
    
    private var bonusGoldCost: Int {
        return raidGates.filter { $0.bonusUsed }.reduce(0) { total, gate in
            return total + RaidData.getBonusLootCost(
                raid: raidName,
                difficulty: gate.difficulty,
                gate: gate.gate
            )
        }
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                // 레이드 이름 + 클리어 표시
                HStack(spacing: 2) {
                    // 모든 관문 완료 여부
                    let allCompleted = isRaidCompleted()
                    
                    // 레이드 명칭 앞에 막 표시 추가
                    Text(getOrderString(for: raidName) + raidName)
                        .font(.subheadline)
                        .foregroundColor(allCompleted ? .gray : .primary)
                        .strikethrough(allCompleted)
                    
                    // 완료 시 체크마크 추가
                    if allCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12))
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }
                    
                    // 더보기 사용 횟수만큼 체크마크 추가
                    if bonusGatesCount > 0 {
                        ForEach(0..<bonusGatesCount, id: \.self) { _ in
                            Image(systemName: "checkmark")
                                .foregroundColor(.orange)
                                .font(.system(size: 12))
                                .fontWeight(.bold)
                        }
                    }
                }
                
                // 관문 요약 (완료된 관문 수 / 전체 관문 수)
                let completedGates = raidGates.filter { $0.isCompleted }.count
                Text("\(completedGates)/\(raidGates.count) 관문 완료")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                HStack {
                    // 더보기 비용 적용 후 골드 계산
                    let netEarnedGold = (earnedGold + displayAdditionalGold) - bonusGoldCost
                    let netTotalGold = (totalGold + additionalGold) - bonusGoldCost
                    
                    // 상위 3개 레이드가 아니면 기본 골드 표시 안 함
                    if isTopRaid && character.isGoldEarner {
                        if isGoldDisabled {
                            // 골드 비활성화된 경우 표시
                            Text("골드 비활성화")
                                .font(.caption)
                                .foregroundColor(.orange)
                                .strikethrough()
                        } else {
                            // 기본 골드 + 추가 골드 - 더보기 비용 표시
                            Text("\(netEarnedGold) / \(netTotalGold) G")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    } else if character.isGoldEarner {
                        // 상위 3개가 아닌 레이드는 추가 골드만 표시
                        let netDisplayAdditionalGold = displayAdditionalGold > bonusGoldCost ? displayAdditionalGold - bonusGoldCost : 0
                        let netAdditionalGold = additionalGold > bonusGoldCost ? additionalGold - bonusGoldCost : 0
                        
                        Text("\(netDisplayAdditionalGold) / \(netAdditionalGold) G")
                            .font(.caption)
                            .foregroundColor(.green)
                            .opacity(additionalGold > 0 ? 1.0 : 0.5)
                    }
                    
                    if additionalGold > 0 && character.isGoldEarner {
                        Text("(+\(additionalGold)G)")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                
                // 골드 획득 불가 표시
                if character.isGoldEarner && (!isTopRaid || isGoldDisabled) {
                    Text("클리어 골드 보상 미획득")
                        .font(.caption2)
                        .foregroundColor(.gray)
                } else if !character.isGoldEarner {
                    Text("골드 획득 캐릭터 아님")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.vertical, 2)
        
        if !isLastRaid {
            Divider()
                .padding(.vertical, 2)
        }
    }
    
    // 레이드 순서 문자열 가져오기
    private func getOrderString(for raidName: String) -> String {
        if raidName.contains("모르둠") { return "3막 " }
        if raidName.starts(with: "2막 아브렐슈드") { return "" }
        if raidName.contains("에기르") { return "1막 " }
        return ""
    }
    
    // 레이드의 모든 관문이 완료되었는지 확인하는 헬퍼 메서드
    private func isRaidCompleted() -> Bool {
        return !raidGates.isEmpty && !raidGates.contains { !$0.isCompleted }
    }
}
