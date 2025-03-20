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
                Section(header: Text("주간 예상 골드 수입")) {
                    HStack {
                        Text("총 예상 골드")
                            .font(.headline)
                        Spacer()
                        Text("\(totalGold) G")
                            .font(.headline)
                            .foregroundColor(.orange)
                    }
                }
                
                // 골드 획득 캐릭터별 상세 내역
                Section(header: Text("캐릭터별 골드 내역")) {
                    if goldEarners.isEmpty {
                        Text("골드 획득 캐릭터가 없습니다")
                            .foregroundColor(.secondary)
                            .italic()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(goldEarners) { character in
                            CharacterGoldRow(character: character)
                        }
                    }
                }
                
                // 안내 섹션
                Section(footer: Text("캐릭터 관리 탭에서 골드 획득 캐릭터를 설정할 수 있습니다.")) {
                    EmptyView()
                }
            }
            .navigationTitle("골드 요약")
        }
    }
    
    // 총 골드 계산
    private var totalGold: Int {
        var total = 0
        
        for character in goldEarners {
            if let raids = character.weeklyRaids {
                for raid in raids {
                    if !raid.isCompleted {
                        total += raid.goldReward
                    }
                }
            }
        }
        
        return total
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
                
                Text("\(characterTotalGold) G")
                    .font(.headline)
                    .foregroundColor(.orange)
            }
            
            Text("\(character.server) • \(character.characterClass) • Lv.\(String(format: "%.0f", character.level))")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // 레이드별 골드 내역
            if let raids = character.weeklyRaids, !raids.isEmpty {
                Divider()
                    .padding(.vertical, 4)
                
                ForEach(raids) { raid in
                    HStack {
                        Text("• \(raid.name) \(raid.difficulty)")
                            .font(.caption)
                            .strikethrough(raid.isCompleted)
                            .foregroundColor(raid.isCompleted ? .secondary : .primary)
                        
                        Spacer()
                        
                        Text("\(raid.goldReward) G")
                            .font(.caption)
                            .foregroundColor(raid.isCompleted ? .secondary : .orange)
                            .strikethrough(raid.isCompleted)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    // 캐릭터별 골드 계산
    private var characterTotalGold: Int {
        var total = 0
        
        if let raids = character.weeklyRaids {
            for raid in raids {
                if !raid.isCompleted {
                    total += raid.goldReward
                }
            }
        }
        
        return total
    }
}
