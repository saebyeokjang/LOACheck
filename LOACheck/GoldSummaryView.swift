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
        NavigationView {
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
            .navigationTitle("골드 요약")
        }
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
        Section(header: Text("주간 예상 골드 수입")) {
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
                
                // 레이드 총 골드 계산
                let raidGolds = groupedGates.map { raidName, gates -> (name: String, gold: Int, earnedGold: Int) in
                    // 골드 합계 안정적으로 계산 (reduce 명시적 사용)
                    let totalGold = gates.reduce(0) { result, gate in
                        // 골드리워드 대신 계산 속성 사용
                        return result + gate.currentGoldReward
                    }
                    
                    // 획득 골드 합계 계산
                    let earnedGold = gates.filter { $0.isCompleted }.reduce(0) { result, gate in
                        return result + gate.currentGoldReward
                    }
                    
                    return (name: raidName, gold: totalGold, earnedGold: earnedGold)
                }.sorted { $0.gold > $1.gold }
                
                // 상위 3개 레이드 이름
                let topRaidNames = raidGolds.prefix(3).map { $0.name }
                
                // 레이드별 정보 표시
                ForEach(raidGolds, id: \.name) { raidInfo in
                    RaidInfoRow(
                        raidInfo: raidInfo,
                        isTopRaid: topRaidNames.contains(raidInfo.name),
                        groupedGates: groupedGates,
                        isLastRaid: raidInfo.name == raidGolds.last?.name
                    )
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// 레이드 정보 행
struct RaidInfoRow: View {
    let raidInfo: (name: String, gold: Int, earnedGold: Int)
    let isTopRaid: Bool
    let groupedGates: [String: [RaidGate]]
    let isLastRaid: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(raidInfo.name)
                    .font(.subheadline)
                    .foregroundColor(isTopRaid ? .primary : .gray)
                
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
                Text("\(raidInfo.earnedGold) / \(raidInfo.gold) G")
                    .font(.caption)
                    .foregroundColor(isTopRaid ? .orange : .gray)
                
                if isTopRaid {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.orange)
                        Text("골드 획득")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                } else {
                    Text("골드 획득 불가")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.vertical, 2)
        .opacity(isTopRaid ? 1.0 : 0.7)
        
        if !isLastRaid {
            Divider()
                .padding(.vertical, 2)
        }
    }
}
