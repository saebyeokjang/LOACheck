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
            GoldSummaryHeader(totalGold: totalGold, earnedGold: earnedGold)
            
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
            
            // 안내 섹션
            Section(footer: Text("캐릭터당 골드 보상이 높은 최대 3개 레이드에서만 골드를 획득할 수 있습니다.")) {
                EmptyView()
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
}

// 골드 요약 헤더 컴포넌트
struct GoldSummaryHeader: View {
    let totalGold: Int
    let earnedGold: Int
    
    var body: some View {
        Section(header: Text("주간 예상 골드 수익")) {
            HStack {
                Text("총 예상 골드")
                    .font(.headline)
                Spacer()
                Text("\(totalGold) G")
                    .font(.headline)
                    .foregroundColor(.orange)
            }
            
            HStack {
                Text("현재 획득 골드")
                    .font(.headline)
                Spacer()
                Text("\(earnedGold) G")
                    .font(.headline)
                    .foregroundColor(.green)
            }
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
                    Text("\(character.calculateEarnedGoldReward()) / \(character.calculateWeeklyGoldReward()) G")
                        .font(.headline)
                        .foregroundColor(.orange)
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
                
                // 레이드 총 골드 계산 및 정렬 로직 개선
                let raidGolds = groupedGates.map { raidName, gates -> (name: String, gold: Int, earnedGold: Int, sortOrder: Int) in
                    // 골드 합계 안정적으로 계산 (reduce 명시적 사용)
                    let totalGold = gates.reduce(0) { result, gate in
                        // 골드리워드 대신 계산 속성 사용
                        return result + gate.currentGoldReward
                    }
                    
                    // 획득 골드 합계 계산
                    let earnedGold = gates.filter { $0.isCompleted }.reduce(0) { result, gate in
                        return result + gate.currentGoldReward
                    }
                    
                    // RaidType 순서 가져오기 - 정렬을 위해 사용
                    let sortOrder = getSortOrderForRaid(raidName)
                    
                    return (name: raidName, gold: totalGold, earnedGold: earnedGold, sortOrder: sortOrder)
                }
                // 정렬 로직 개선: 먼저 RaidData의 sortOrder 기준으로 정렬 (높은 순)
                .sorted { $0.sortOrder > $1.sortOrder }
                
                // 상위 3개 레이드 이름 (골드 높은 순 기준)
                let topRaidNames = character.getTopRaidNames()
                
                // 레이드별 정보 표시
                ForEach(raidGolds, id: \.name) { raidInfo in
                    RaidInfoRow(
                        character: character,
                        raidInfo: (name: raidInfo.name, gold: raidInfo.gold, earnedGold: raidInfo.earnedGold),
                        isTopRaid: topRaidNames.contains(raidInfo.name),
                        groupedGates: groupedGates,
                        isLastRaid: raidInfo.name == raidGolds.last?.name
                    )
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    // 레이드 정렬을 위한 우선순위 값 가져오기
    private func getSortOrderForRaid(_ raidName: String) -> Int {
        // RaidData.RaidType 열거형에서 sortOrder 값 활용
        if let raidType = RaidData.RaidType.allCases.first(where: { $0.rawValue == raidName }) {
            return raidType.sortOrder
        }
        return 0 // 기본값
    }
}

// 레이드 정보 행
struct RaidInfoRow: View {
    let character: CharacterModel
    let raidInfo: (name: String, gold: Int, earnedGold: Int)
    let isTopRaid: Bool
    let groupedGates: [String: [RaidGate]]
    let isLastRaid: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                // 레이드 이름 + 클리어 표시
                HStack(spacing: 4) {
                    // 레이드 이름에 취소선 추가 (모든 관문 완료 시)
                    let allCompleted = isRaidCompleted()
                    
                    Text(raidInfo.name)
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
                }
                
                if let raidGates = groupedGates[raidInfo.name] {
                    // 관문 요약 (완료된 관문 수 / 전체 관문 수)
                    let completedGates = raidGates.filter { $0.isCompleted }.count
                    Text("\(completedGates)/\(raidGates.count) 관문 완료")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                // 추가 골드 가져오기 (CharacterModel에서)
                let additionalGold = character.getAdditionalGold(for: raidInfo.name)
                
                // 해당 레이드의 하나라도 완료된 관문이 있는지 확인
                let hasCompletedGates = (groupedGates[raidInfo.name] ?? []).contains { $0.isCompleted }
                
                // 추가 골드 표시 (완료된 관문이 있을 때만)
                let displayAdditionalGold = hasCompletedGates ? additionalGold : 0
                
                HStack(spacing: 4) {
                    if isTopRaid {
                        // 상위 3개 레이드는 기본 골드 + 추가 골드 표시
                        Text("\(raidInfo.earnedGold + displayAdditionalGold) / \(raidInfo.gold + additionalGold) G")
                            .font(.caption)
                            .foregroundColor(.orange)
                    } else {
                        // 그 외 레이드는 추가 골드만 표시
                        Text("\(displayAdditionalGold) / \(additionalGold) G")
                            .font(.caption)
                            .foregroundColor(additionalGold > 0 ? .green : .gray)
                    }
                    
                    if additionalGold > 0 {
                        Text("(+\(additionalGold)G)")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                
                // 골드 획득 불가 표시
                if !isTopRaid {
                    Text("클리어 골드 획득 불가")
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
    
    // 레이드의 모든 관문이 완료되었는지 확인하는 헬퍼 메서드
    private func isRaidCompleted() -> Bool {
        if let raidGates = groupedGates[raidInfo.name] {
            return !raidGates.isEmpty && !raidGates.contains { !$0.isCompleted }
        }
        return false
    }
}
