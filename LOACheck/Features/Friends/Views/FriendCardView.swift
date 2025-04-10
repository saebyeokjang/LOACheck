//
//  FriendCardView.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 4/10/25.
//

import SwiftUI

struct FriendCardView: View {
    var friendWithCharacters: FriendWithCharacters
    var onRemove: (Friend) -> Void
    
    @State private var showRaidSummary = false
    
    // 대표 캐릭터 (사용자가 지정한 대표 캐릭터 - displayName과 이름이 일치하는 캐릭터)
    private var representativeCharacter: CharacterModel? {
        // 1. 친구의 displayName과 일치하는 캐릭터 찾기
        if let character = friendWithCharacters.characters.first(where: { $0.name == friendWithCharacters.friend.displayName }) {
            return character
        }
        
        // 2. 일치하는 캐릭터가 없으면 레벨이 가장 높은 캐릭터 반환 (대체 방안)
        return friendWithCharacters.characters.sorted(by: { $0.level > $1.level }).first
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 친구 정보 헤더
            HStack {
                VStack(alignment: .leading) {
                    Text(friendWithCharacters.friend.displayName)
                        .font(.headline)
                    
                    Text("친구 추가 날짜: \(friendWithCharacters.friend.timestamp.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 삭제 버튼
                Button(action: {
                    onRemove(friendWithCharacters.friend)
                }) {
                    Image(systemName: "person.crop.circle.badge.xmark")
                        .foregroundColor(.red)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
            .padding(.horizontal)
            .padding(.top, 12)
            
            Divider()
                .padding(.horizontal)
            
            // 대표 캐릭터만 표시
            if let character = representativeCharacter {
                Button(action: {
                    showRaidSummary = true
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(character.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            Text("\(character.server) • \(character.characterClass)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Lv. \(String(format: "%.2f", character.level))")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                            
                            // 골드 획득 캐릭터인 경우 골드 표시
                            if character.isGoldEarner, let raidGates = character.raidGates, !raidGates.isEmpty {
                                let earnedGold = character.calculateEarnedGoldReward()
                                let totalGold = character.calculateWeeklyGoldReward()
                                
                                // 기본 + 추가 골드 합산하여 표시
                                HStack(spacing: 4) {
                                    Text("\(earnedGold)/\(totalGold) G")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                    }
                    .contentShape(Rectangle())
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                Text("표시할 캐릭터가 없습니다")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .sheet(isPresented: $showRaidSummary) {
            NavigationStack {
                FriendRaidSummaryView(
                    friend: friendWithCharacters.friend,
                    characters: friendWithCharacters.characters
                )
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("닫기") {
                            showRaidSummary = false
                        }
                    }
                }
            }
        }
    }
}

// 친구 캐릭터 행
struct FriendCharacterRow: View {
    var character: CharacterModel
    @State private var showCharacterDetail = false
    
    var body: some View {
        Button(action: {
            showCharacterDetail = true
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(character.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text("\(character.server) • \(character.characterClass)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Lv. \(String(format: "%.2f", character.level))")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                    
                    // 골드 획득 캐릭터인 경우 골드 표시
                    if character.isGoldEarner, let raidGates = character.raidGates, !raidGates.isEmpty {
                        let earnedGold = character.calculateEarnedGoldReward()
                        let totalGold = character.calculateWeeklyGoldReward()
                        
                        // 기본 + 추가 골드 합산하여 표시
                        HStack(spacing: 4) {
                            Text("\(earnedGold)/\(totalGold) G")
                                .font(.caption)
                                .foregroundColor(.orange)
                            
                            // 추가 골드가 있는 경우에만 표시
                            let additionalGold = getAdditionalGoldSum(character)
                            if additionalGold > 0 {
                                Text("(+\(additionalGold))")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.vertical, 4)
        .sheet(isPresented: $showCharacterDetail) {
            NavigationStack {
                FriendCharacterDetailView(character: character)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("닫기") {
                                showCharacterDetail = false
                            }
                        }
                    }
            }
        }
    }
    
    // 완료된 레이드에 대한 추가 골드 계산
    private func getAdditionalGoldSum(_ character: CharacterModel) -> Int {
        guard let raidGates = character.raidGates else { return 0 }
        
        let groupedGates = Dictionary(grouping: raidGates) { $0.raid }
        
        return groupedGates.filter { raidName, gates in
            // 완료된 관문이 있는 레이드만 필터링
            return gates.contains { $0.isCompleted }
        }.reduce(0) { result, raid in
            // 해당 레이드의 추가 수익 합산
            return result + character.getAdditionalGold(for: raid.key)
        }
    }
}
