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
                VStack(spacing: 12) {
                    HStack {
                        Text(friend.displayName)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Spacer()
                    }
                    
                    // 골드 획득 요약 - 내 골드 현황과 동일한 방식으로 수정
                    VStack(spacing: 8) {
                        HStack {
                            Text("주간 예상 골드 수익")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                        }
                        
                        Divider()
                        
                        HStack {
                            Text("총 예상 골드")
                                .font(.headline)
                            Spacer()
                            Text("\(totalExpectedGold) G")
                                .font(.headline)
                                .foregroundColor(.orange)
                        }
                        
                        HStack {
                            Text("현재 획득 골드")
                                .font(.headline)
                            Spacer()
                            Text("\(totalEarnedGold) G")
                                .font(.headline)
                                .foregroundColor(.green)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
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
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Lv. \(String(format: "%.2f", character.level))")
                        .font(.caption)
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
                
                // WeeklyRaidsView와 동일한 형태의 RaidListCardView 사용
                // WeeklyRaidsView의 RaidCardView와 유사하게 변경
                ForEach(sortedRaids, id: \.self) { raidName in
                    if let gates = groupedGates[raidName] {
                        FriendRaidCardView(
                            raidName: raidName,
                            gates: gates.sorted(by: { $0.gate < $1.gate }),
                            character: character,
                            isTopRaid: topRaidNames.contains(raidName)
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
}

// 친구 레이드 카드 뷰
struct FriendRaidCardView: View {
    var raidName: String
    var gates: [RaidGate]
    var character: CharacterModel
    var isTopRaid: Bool
    
    @State private var isAllCompleted: Bool = false
    
    // 추가 골드 계산
    private var additionalGold: Int {
        return character.getAdditionalGold(for: raidName)
    }
    
    // 레이드 총 골드 계산
    private var totalGold: Int {
        return gates.reduce(0) { $0 + $1.goldReward }
    }
    
    // 획득한 골드 계산
    private var earnedGold: Int {
        return gates.filter { $0.isCompleted }.reduce(0) { $0 + $1.goldReward }
    }
    
    // 완료된 관문이 있는지 확인
    private var hasCompletedGates: Bool {
        return gates.contains { $0.isCompleted }
    }
    
    // 표시할 추가 골드 (완료된 관문이 있을 때만)
    private var displayAdditionalGold: Int {
        return hasCompletedGates ? additionalGold : 0
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 레이드 헤더
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(getOrderString(for: raidName)) \(raidName)")
                        .font(.headline)
                        .foregroundColor(isTopRaid || !character.isGoldEarner ? .primary : .gray)
                    
                    if character.isGoldEarner {
                        HStack {
                            // 상위 3개 레이드가 아니면 기본 골드 표시 안 함
                            if isTopRaid {
                                Text("\(earnedGold + displayAdditionalGold) / \(totalGold + additionalGold) G")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            } else {
                                // 상위 3개가 아닌 레이드는 추가 골드만 표시
                                Text("\(displayAdditionalGold) / \(additionalGold) G")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                    .opacity(additionalGold > 0 ? 1.0 : 0.0)
                            }
                            
                            if additionalGold > 0 {
                                Text("(+\(additionalGold)G)")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                    .opacity(1.0)
                            }
                        }
                    }
                }
                
                Spacer()
                
                // 완료 상태 표시
                ZStack {
                    // 프레임 배경과 테두리
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isAllGatesCompleted() ? Color.green.opacity(0.1) : Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(isAllGatesCompleted() ? Color.green.opacity(0.3) : Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .frame(width: 32, height: 32)
                    
                    // 체크 표시 (완료 시)
                    if isAllGatesCompleted() {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.green)
                    }
                }
                .foregroundColor(isAllGatesCompleted() ? .secondary : .primary)
                .cornerRadius(4)
                .frame(width: 30, height: 30)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isTopRaid && character.isGoldEarner ?
                        Color.yellow.opacity(0.05) : Color.gray.opacity(0.05))
            
            // 레이드 관문 그리드
            let displayGates = getSortedGates()
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: displayGates.count > 0 ? min(4, displayGates.count) : 1), spacing: 0) {
                ForEach(displayGates) { gate in
                    FriendGateButton(
                        gate: gate,
                        isGoldEarner: character.isGoldEarner,
                        isTopRaid: isTopRaid
                    )
                }
            }
        }
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        .padding(.vertical, 4)
        .opacity(isTopRaid || !character.isGoldEarner ? 1.0 : 0.7)  // 상위 레이드가 아니면 흐리게
        .onAppear {
            // 모든 관문이 완료되었는지 확인
            updateCompletionStatus()
            
            // 디버깅 코드 (onAppear 내부로 이동)
            debugPrint("Character \(character.name) additionalGoldMap: \(character.additionalGoldMap)")
            debugPrint("Raid \(raidName) additionalGold: \(additionalGold)")
        }
    }
    
    // 정렬된 관문
    private func getSortedGates() -> [RaidGate] {
        // 관문 번호로 정렬
        return gates.sorted { $0.gate < $1.gate }
    }
    
    // 레이드 순서 문자열 가져오기
    private func getOrderString(for raidName: String) -> String {
        if raidName.contains("모르둠") { return "3막" }
        if raidName.starts(with: "2막 아브렐슈드") { return "" }
        if raidName.contains("에기르") { return "1막" }
        return ""
    }
    
    // 모든 관문이 완료되었는지 확인
    private func isAllGatesCompleted() -> Bool {
        // 모든 관문이 완료되어 있는지 확인
        return !gates.isEmpty && !gates.contains { !$0.isCompleted }
    }
    
    // 완료 상태 업데이트
    private func updateCompletionStatus() {
        isAllCompleted = isAllGatesCompleted()
    }
}

// 관문 버튼 (보기만 가능한 버전)
struct FriendGateButton: View {
    var gate: RaidGate
    var isGoldEarner: Bool
    var isTopRaid: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            // 관문 번호와 난이도 표시
            HStack(spacing: 4) {
                Text("\(gate.gate + 1)관문")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .strikethrough(gate.isCompleted)
                
                // 난이도 텍스트로 표시
                Text(gate.difficulty)
                    .font(.caption2)
                    .foregroundColor(getDifficultyColor(gate.difficulty))
                    .strikethrough(gate.isCompleted)
            }
            
            // 골드 보상
            Text("\(gate.goldReward)G")
                .font(.caption)
                .foregroundColor(isTopRaid && isGoldEarner ? .orange : .gray)
                .strikethrough(gate.isCompleted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(getBackgroundColor())
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(getBorderColor(), lineWidth: 1)
        )
        .foregroundColor(gate.isCompleted ? .secondary : .primary)
        .cornerRadius(4)
        .padding(4)
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
    
    // 배경색 결정
    private func getBackgroundColor() -> Color {
        if gate.isCompleted {
            return Color.gray.opacity(0.1)
        } else {
            return Color.white
        }
    }
    
    // 테두리 색상 결정
    private func getBorderColor() -> Color {
        if gate.isCompleted {
            return Color.gray.opacity(0.3)
        } else {
            return gate.difficulty == "하드" ? Color.red.opacity(0.3) :
            gate.difficulty == "노말" ? Color.blue.opacity(0.3) :
            Color.green.opacity(0.3)
        }
    }
}
