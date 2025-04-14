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
    @State private var showDeleteConfirmation = false
    
    // 대표 캐릭터 (사용자가 지정한 대표 캐릭터 - displayName과 이름이 일치하는 캐릭터)
    private var representativeCharacter: CharacterModel? {
        // 1. 친구의 displayName과 일치하는 캐릭터 찾기
        if let character = friendWithCharacters.characters.first(where: { $0.name == friendWithCharacters.friend.displayName }) {
            return character
        }
        
        // 2. 일치하는 캐릭터가 없으면 레벨이 가장 높은 캐릭터 반환 (대체 방안)
        return friendWithCharacters.characters.sorted(by: { $0.level > $1.level }).first
    }
    
    // 원정대 전체 골드 계산
    private var totalExpectedGold: Int {
        var total = 0
        
        for character in friendWithCharacters.characters {
            if character.isGoldEarner {
                total += character.calculateWeeklyGoldReward()
            }
        }
        
        return total
    }
    
    // 원정대 전체 획득 골드 계산
    private var totalEarnedGold: Int {
        var total = 0
        
        for character in friendWithCharacters.characters {
            if character.isGoldEarner {
                total += character.calculateEarnedGoldReward()
            }
        }
        
        return total
    }
    
    var body: some View {
        Button(action: {
            showRaidSummary = true
        }) {
            HStack {
                // 대표 캐릭터 이름 (친구의 displayName)
                VStack(alignment: .leading, spacing: 4) {
                    Text(friendWithCharacters.friend.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    // 서버, 클래스, 레벨 정보
                    if let character = representativeCharacter {
                        Text("\(character.server) • \(character.characterClass)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Lv.\(String(format: "%.2f", character.level))")
                            .font(.caption)
                    }
                }
                
                Spacer()
                
                // 전체 원정대 골드 정보
                if totalExpectedGold > 0 {
                    Text("\(totalEarnedGold) / \(totalExpectedGold) G")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .cornerRadius(8)
                }
                
                Image(systemName: "chevron.right")
                    .font(.body)
                    .foregroundColor(.gray)
            }
            .contentShape(Rectangle())
            .padding(.vertical, 18)
            .padding(.horizontal, 16)
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("친구 삭제", systemImage: "person.crop.circle.badge.xmark")
            }
        }
        .alert("친구 삭제", isPresented: $showDeleteConfirmation) {
            Button("취소", role: .cancel) {}
            Button("삭제", role: .destructive) {
                onRemove(friendWithCharacters.friend)
            }
        } message: {
            Text("\(friendWithCharacters.friend.displayName)님을 친구 목록에서 삭제하시겠습니까?")
        }
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
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
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
