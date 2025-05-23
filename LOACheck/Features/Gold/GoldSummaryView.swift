//
//  GoldSummaryView.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 3/20/25.
//

import SwiftUI
import SwiftData

struct GoldSummaryView: View {
    @Query var goldEarners: [CharacterModel]
    
    init() {
        var descriptor = FetchDescriptor<CharacterModel>(predicate: #Predicate<CharacterModel> { $0.isGoldEarner })
        descriptor.sortBy = [SortDescriptor(\CharacterModel.level, order: .reverse)]
        _goldEarners = Query(descriptor)
    }
    
    var body: some View {
        List {
            // 총 예상 골드 섹션
            GoldSummaryHeader(
                totalGold: totalGold,
                earnedGold: earnedGold,
                bonusCost: totalBonusCost
            )
            
            // 골드 획득 캐릭터별 상세 내역
            Section(header: Text("캐릭터별 골드 내역")) {
                if goldEarners.isEmpty {
                    EmptyGoldEarnersView()
                } else {
                    ForEach(goldEarners) { character in
                        CharacterGoldRow(character: character)
                    }
                }
            }
        }
        .navigationTitle("주간 획득 골드")
    }
    
    // 총 예상 골드
    private var totalGold: Int {
        var total = 0
        
        for character in goldEarners {
            total += character.calculateWeeklyGoldReward()
        }
        
        return total
    }
    
    // 이미 획득한 골드
    private var earnedGold: Int {
        var total = 0
        
        for character in goldEarners {
            total += character.calculateEarnedGoldReward()
        }
        
        return total
    }
    
    // 더보기 총 비용
    private var totalBonusCost: Int {
        var total = 0
        
        for character in goldEarners {
            total += character.calculateBonusLootCost()
        }
        
        return total
    }
}

// 골드 요약 헤더 컴포넌트
struct GoldSummaryHeader: View {
    let totalGold: Int
    let earnedGold: Int
    let bonusCost: Int
    
    var body: some View {
        Section(header: Text("주간 예상 골드 수익")) {
            VStack(spacing: 0) {
                HStack {
                    Text("현재 획득 골드")
                        .font(.headline)
                    Spacer()
                    Text("\(earnedGold)G")
                        .font(.headline)
                        .foregroundColor(.green)
                }
                .padding(.vertical, 10)
                
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(height: 0.5)
                    .padding(.leading, -16)
                    .padding(.trailing, -16)
                
                HStack {
                    Text("총 예상 골드")
                        .font(.headline)
                    Spacer()
                    Text("\(totalGold)G")
                        .font(.headline)
                        .foregroundColor(.orange)
                }
                .padding(.vertical, 10)
            }
            .padding(.top, 0)
            .padding(.bottom, 0)
            .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
        }
    }
}

// 골드 획득 캐릭터가 없을 때 표시할 뷰
struct EmptyGoldEarnersView: View {
    var body: some View {
        Text("골드 획득 캐릭터가 없습니다")
            .foregroundColor(.secondary)
            .italic()
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 8)
    }
}

struct CharacterGoldRow: View {
    var character: CharacterModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 캐릭터 기본 정보
            HStack {
                Text(character.name)
                    .font(.headline)
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    let bonusCost = character.calculateBonusLootCost()
                    
                    if bonusCost > 0 {
                        // 더보기 비용이 있는 경우 순수익 표시
                        // 기존 골드 표시
                        Text("\(character.calculateEarnedGoldReward()) / \(character.calculateWeeklyGoldReward())G")
                            .font(.headline)
                            .foregroundColor(.orange)
                    } else {
                        // 기존 골드 표시
                        Text("\(character.calculateEarnedGoldReward()) / \(character.calculateWeeklyGoldReward())G")
                            .font(.headline)
                            .foregroundColor(.orange)
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
                
                // RaidType.sortOrder 기준으로 내림차순 정렬 (WeeklyRaidsView와 동일한 정렬 사용)
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
                        RaidInfoRow(
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
    // 캐릭터의 더보기 비용 계산
    private func calculateCharacterBonusCost() -> Int {
        guard let gates = character.raidGates else { return 0 }
        
        return gates.filter { $0.bonusUsed }.reduce(0) { total, gate in
            return total + RaidData.getBonusLootCost(
                raid: gate.raid,
                difficulty: gate.difficulty,
                gate: gate.gate
            )
        }
    }
}

// 레이드 정보 행
struct RaidInfoRow: View {
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
    
    // 레이드의 더보기 사용 관문 수와 비용
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
                
                // 더보기 정보 추가
                if bonusGatesCount > 0 {
                    Text("더보기: \(bonusGatesCount)회 (-\(bonusGoldCost)G)")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                HStack {
                    // 더보기 비용 적용 후 골드 계산
                    let netEarnedGold = (earnedGold + displayAdditionalGold) - bonusGoldCost
                    let netTotalGold = (totalGold + additionalGold) - bonusGoldCost
                    
                    // 상위 3개 레이드가 아니면 기본 골드 표시 안 함
                    if isTopRaid {
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
                    } else {
                        // 상위 3개가 아닌 레이드는 추가 골드만 표시
                        Text("\(displayAdditionalGold) / \(additionalGold) G")
                            .font(.caption)
                            .foregroundColor(.green)
                            .opacity(additionalGold > 0 ? 1.0 : 0.5)
                    }
                    
                    if additionalGold > 0 {
                        Text("(+\(additionalGold)G)")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                
                // 골드 획득 불가 표시
                if !isTopRaid {
                    Text("클리어 골드 보상 미획득")
                        .font(.caption2)
                        .foregroundColor(.gray)
                } else if isGoldDisabled {
                    Text("클리어 골드 보상 미획득")
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
