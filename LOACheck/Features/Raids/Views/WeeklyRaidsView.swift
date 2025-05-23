//
//  WeeklyRaidsView.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 3/21/25.
//

import SwiftUI
import SwiftData
import FirebaseAnalytics

struct WeeklyRaidsView: View {
    var character: CharacterModel
    @State private var isShowingRaidSettings = false
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 주간 레이드 헤더
            HStack {
                Text("주간 레이드")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(Color.textPrimary)
                
                Spacer()
                
                Button(action: {
                    isShowingRaidSettings = true
                }) {
                    // 다크모드에서 더 잘 보이도록 아이콘 색상 조정
                    Image(systemName: "gearshape.fill")
                        .foregroundColor(colorScheme == .dark ? .gray.opacity(0.8) : .gray)
                }
            }
            
            Divider()
                .background(Color.dividerColor)
            
            if let raidGates = character.raidGates, !raidGates.isEmpty {
                // 레이드별로 그룹화 및 표시
                RaidListCardView(character: character, raidGates: raidGates)
            } else {
                // 설정된 레이드가 없을 때 안내 메시지
                emptyRaidView
            }
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 5, x: 0, y: 2)
        .sheet(isPresented: $isShowingRaidSettings) {
            RaidSettingsView(character: character)
        }
    }
    
    // 레이드가 없을 때 보여주는 뷰
    private var emptyRaidView: some View {
        HStack {
            Spacer()
            VStack(spacing: 12) {
                // 다크모드에서 더 잘 보이도록 아이콘 색상 조정
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 30))
                    .foregroundColor(colorScheme == .dark ? .gray.opacity(0.8) : .gray)
                
                Text("설정된 레이드가 없습니다")
                    .foregroundColor(Color.textSecondary)
                
                Text("레이드 설정 버튼을 눌러 레이드를 추가하세요")
                    .font(.caption)
                    .foregroundColor(Color.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 20)
            Spacer()
        }
        .background(colorScheme == .dark ? Color.black.opacity(0.1) : Color.gray.opacity(0.03))
        .cornerRadius(8)
    }
}

// 레이드 리스트 카드 뷰
struct RaidListCardView: View {
    var character: CharacterModel
    var raidGates: [RaidGate]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        // 레이드별로 그룹화
        let groupedGates = Dictionary(grouping: raidGates) { $0.raid }
        
        // 레이드 순서를 RaidData.RaidType.sortOrder 기준으로 정렬
        let sortedRaidNames = getSortedRaidNames(from: groupedGates)
        
        // 골드 획득할 수 있는 상위 3개 레이드 가져오기
        let topRaidNames = character.getTopRaidNames()
        
        // 전체 골드 계산 - CharacterModel 메서드 사용
        let totalGold = character.calculateWeeklyGoldReward()
        let earnedTotalGold = character.calculateEarnedGoldReward()
        
        VStack(spacing: 16) {
            // 골드 요약 정보
            if character.isGoldEarner {
                goldSummaryView(earnedGold: earnedTotalGold, totalGold: totalGold)
            }
            
            // 각 레이드 카드 (순서 고정)
            ForEach(sortedRaidNames, id: \.self) { raidName in
                if let gates = groupedGates[raidName] {
                    RaidCardView(
                        raidName: raidName,
                        gates: gates,
                        isGoldEarner: character.isGoldEarner,
                        isTopRaid: topRaidNames.contains(raidName),
                        character: character
                    )
                }
            }
            
            // 골드 획득 캐릭터가 아닌 경우 알림 표시
            if !character.isGoldEarner && !raidGates.isEmpty {
                Text("골드 획득 캐릭터로 지정되지 않아 골드를 획득할 수 없습니다")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
        }
    }
    
    // 골드 요약 뷰
    private func goldSummaryView(earnedGold: Int, totalGold: Int) -> some View {
        HStack {
            Text("획득량 / 주간 골드")
                .font(.caption)
                .foregroundColor(Color.textSecondary)
            
            Spacer()
            
            HStack(spacing: 4) {
                // 다크모드에서 색상 조정
                Image(systemName: "circle.fill")
                    .font(.system(size: 8))
                    .foregroundColor(colorScheme == .dark ? .yellow.opacity(0.8) : .yellow)
                
                Text("\(earnedGold) / \(totalGold) G")
                    .fontWeight(.semibold)
                    .foregroundColor(colorScheme == .dark ? .orange.opacity(0.9) : .orange)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        // 다크모드에서 더 잘 보이도록 배경색 투명도 조정
        .background(Color.yellow.opacity(colorScheme == .dark ? 0.15 : 0.1))
        .cornerRadius(8)
    }
    
    // 레이드 순서 정렬
    private func getSortedRaidNames(from groupedGates: [String: [RaidGate]]) -> [String] {
        return groupedGates.keys.sorted { raid1, raid2 in
            // RaidType 찾기
            guard let type1 = RaidData.RaidType.allCases.first(where: { $0.rawValue == raid1 }),
                  let type2 = RaidData.RaidType.allCases.first(where: { $0.rawValue == raid2 }) else {
                return raid1 < raid2 // 기본 알파벳 순
            }
            
            // sortOrder 기준으로 내림차순 정렬 (높은 숫자가 먼저 나오도록)
            return type1.sortOrder > type2.sortOrder
        }
    }
}

// 레이드 카드 뷰
struct RaidCardView: View {
    var raidName: String
    var gates: [RaidGate]
    var isGoldEarner: Bool
    var isTopRaid: Bool
    var character: CharacterModel
    
    @State private var isAllCompleted: Bool = false
    @State private var showAdditionalGoldSheet = false
    @Environment(\.colorScheme) private var colorScheme
    
    // 계산 프로퍼티들
    private var isGoldDisabled: Bool {
        return gates.first?.isGoldDisabled ?? false
    }
    
    private var totalGold: Int {
        return gates.reduce(0) { $0 + $1.currentGoldReward }
    }
    
    private var earnedGold: Int {
        return gates.filter { $0.isCompleted }.reduce(0) { $0 + $1.currentGoldReward }
    }
    
    private var additionalGold: Int {
        return character.getAdditionalGold(for: raidName)
    }
    
    private var hasCompletedGates: Bool {
        return gates.contains { $0.isCompleted }
    }
    
    private var displayAdditionalGold: Int {
        return hasCompletedGates ? additionalGold : 0
    }
    
    private var displayGates: [RaidGate] {
        return getSortedGates()
    }
    
    // 더보기 비용 계산
    private var bonusGoldCost: Int {
        return gates.filter { $0.bonusUsed }.reduce(0) { total, gate in
            return total + RaidData.getBonusLootCost(
                raid: raidName,
                difficulty: gate.difficulty,
                gate: gate.gate
            )
        }
    }
    
    // 더보기 사용 관문 수
    private var bonusGatesCount: Int {
        return gates.filter { $0.bonusUsed }.count
    }
    
    private var gridColumns: [GridItem] {
        let count = displayGates.count > 0 ? min(4, displayGates.count) : 1
        return Array(repeating: GridItem(.flexible()), count: count)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 레이드 헤더
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                        // 레이드 이름과 더보기 체크마크 표시
                        HStack(spacing: 2) {
                            Text("\(getOrderString(for: raidName)) \(raidName) ")
                                .font(.headline)
                                .foregroundColor(Color.textPrimary)
                            
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
                    
                    // 골드 정보 뷰
                    if isGoldEarner {
                        goldInfoView()
                    }
                }
                
                Spacer()
                
                // 버튼 영역
                HStack {
                    // 추가 수익 버튼
                    if isGoldEarner {
                        additionalGoldButton
                    }
                    
                    // 전체 완료 버튼
                    completeAllButton
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            // 다크모드에서 헤더 배경색 조정
            .background(headerBackgroundColor)
            
            // 레이드 관문 그리드
            LazyVGrid(columns: gridColumns, spacing: 0) {
                ForEach(displayGates) { gate in
                    GateButton(
                        gate: gate,
                        isGoldEarner: isGoldEarner,
                        isTopRaid: isTopRaid,
                        isGoldDisabled: isGoldDisabled,
                        allGates: displayGates
                    )
                }
            }
        }
        .background(Color.cardBackground)
        .cornerRadius(10)
        // 다크모드에서 그림자 조정
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.05), radius: 2, x: 0, y: 1)
        .padding(.vertical, 4)
        .opacity(isTopRaid || !isGoldEarner ? 1.0 : 0.7)  // 상위 레이드가 아니면 흐리게
        .onAppear {
            // 모든 관문이 완료되었는지 확인
            updateCompletionStatus()
        }
        .onChange(of: gates.map { $0.isCompleted }) { _, _ in
            // 관문 완료 상태가 변경될 때마다 전체 상태 갱신
            updateCompletionStatus()
        }
        .sheet(isPresented: $showAdditionalGoldSheet) {
            AdditionalGoldInputView(character: character, raidName: raidName)
        }
    }
    
    // 헤더 배경색 계산
    private var headerBackgroundColor: Color {
        if isTopRaid && isGoldEarner {
            return colorScheme == .dark ? Color.yellow.opacity(0.08) : Color.yellow.opacity(0.05)
        } else {
            return colorScheme == .dark ? Color.gray.opacity(0.08) : Color.gray.opacity(0.05)
        }
    }
    
    // 추가 골드 버튼
    private var additionalGoldButton: some View {
        Button(action: {
            showAdditionalGoldSheet = true
        }) {
            HStack(spacing: 4) {
                Image(systemName: "plus").font(.title3)
            }
            // 다크모드에서 색상 조정
            .foregroundColor(colorScheme == .dark ? .green.opacity(0.9) : .green)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.trailing, 8)
    }
    
    // 전체 완료 버튼
    private var completeAllButton: some View {
        Button(action: {
            toggleAllGates()
        }) {
            ZStack {
                // 프레임 배경과 테두리
                RoundedRectangle(cornerRadius: 4)
                    .fill(isAllCompleted ?
                          Color.green.opacity(colorScheme == .dark ? 0.2 : 0.1) :
                            (colorScheme == .dark ? Color.black.opacity(0.2) : Color.white))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(isAllCompleted ?
                                    Color.green.opacity(colorScheme == .dark ? 0.5 : 0.3) :
                                        Color.gray.opacity(colorScheme == .dark ? 0.5 : 0.3), lineWidth: 1)
                    )
                    .frame(width: 32, height: 32)
                
                // 체크 표시 (완료 시)
                if isAllCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.green)
                }
            }
        }
        .foregroundColor(isAllCompleted ? Color.textSecondary : Color.textPrimary)
        .cornerRadius(4)
        .frame(width: 30, height: 30)
        .contentShape(Rectangle())
        .buttonStyle(PlainButtonStyle())
    }
    
    // 골드 정보 표시
    @ViewBuilder
    private func goldInfoView() -> some View {
        HStack {
            if isGoldDisabled || !isTopRaid {
                // 골드 비활성화 또는 상위 레이드가 아님 - 추가 골드만 표시
                if additionalGold > 0 {
                    // 더보기 비용 차감
                    let netDisplayAdditionalGold = displayAdditionalGold > bonusGoldCost ? displayAdditionalGold - bonusGoldCost : 0
                    let netAdditionalGold = additionalGold > bonusGoldCost ? additionalGold - bonusGoldCost : 0
                    
                    Text("\(netDisplayAdditionalGold) / \(netAdditionalGold) G")
                        .font(.caption)
                        .foregroundColor(colorScheme == .dark ? .green.opacity(0.9) : .green)
                    
                    Text("(+\(additionalGold)G)")
                        .font(.caption)
                        .foregroundColor(colorScheme == .dark ? .green.opacity(0.9) : .green)
                }
            } else {
                // 상위 레이드 - 클리어 골드 + 추가 골드 - 더보기 비용
                let netEarnedGold = (earnedGold + displayAdditionalGold) - bonusGoldCost
                let netTotalGold = (totalGold + additionalGold) - bonusGoldCost
                
                Text("\(netEarnedGold) / \(netTotalGold) G")
                    .font(.caption)
                    .foregroundColor(colorScheme == .dark ? .orange.opacity(0.9) : .orange)
                
                if additionalGold > 0 {
                    Text("(+\(additionalGold)G)")
                        .font(.caption)
                        .foregroundColor(colorScheme == .dark ? .green.opacity(0.9) : .green)
                }
            }
        }
    }
    
    // 완료 상태 업데이트
    private func updateCompletionStatus() {
        isAllCompleted = !displayGates.isEmpty && !displayGates.contains(where: { !$0.isCompleted })
    }
    
    // 정렬된 관문
    private func getSortedGates() -> [RaidGate] {
        // 관문 번호로 정렬
        return gates.sorted { $0.gate < $1.gate }
    }
    
    // 레이드 순서 문자열 가져오기
    private func getOrderString(for raidName: String) -> String {
        if raidName.contains("모르둠") { return "3막 " }
        if raidName.starts(with: "2막 아브렐슈드") { return "" }
        if raidName.contains("에기르") { return "1막 " }
        return ""
    }
    
    // 모든 관문 토글
    private func toggleAllGates() {
        // 모든 관문의 상태를 현재와 반대로
        let newState = !isAllCompleted
        
        if newState {
            // 모두 완료로 설정
            for gate in displayGates {
                gate.isCompleted = true
                gate.lastCompletedAt = Date()
            }
        } else {
            // 모두 미완료로 설정
            for gate in displayGates {
                gate.isCompleted = false
                gate.lastCompletedAt = nil
                
                // 더보기 사용 초기화
                gate.bonusUsed = false
            }
        }
        
        isAllCompleted = newState
        
        DataSyncManager.shared.markLocalChanges()
    }
}

// 관문 버튼
struct GateButton: View {
    @Bindable var gate: RaidGate
    var isGoldEarner: Bool
    var isTopRaid: Bool
    var isGoldDisabled: Bool
    var allGates: [RaidGate]
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: {
            toggleGate()
        }) {
            VStack(spacing: 4) {
                // 관문 번호와 난이도 표시
                HStack(spacing: 4) {
                    Text("\(gate.gate + 1)관문")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .strikethrough(gate.isCompleted)
                        .foregroundColor(gate.isCompleted ? Color.textSecondary : Color.textPrimary)
                    
                    // 난이도 텍스트로 표시 - 다크모드에서 색상 조정
                    Text(gate.difficulty)
                        .font(.caption2)
                        .foregroundColor(getDifficultyColor())
                        .strikethrough(gate.isCompleted)
                }
                
                // 골드 보상 - 비활성화 상태 표시
                HStack(spacing: 2) {
                    Text("\(gate.goldReward)G")
                        .font(.caption)
                        .foregroundColor(getGoldRewardColor())
                        .strikethrough(gate.isCompleted || (isGoldDisabled && isTopRaid && isGoldEarner))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(getBackgroundColor())
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(getBorderColor(), lineWidth: 1)
            )
            .foregroundColor(gate.isCompleted ? Color.textSecondary : Color.textPrimary)
            .cornerRadius(4)
        }
        .padding(4)
        .disabled(!canToggleGate())  // 이전 관문이 완료되지 않으면 비활성화
    }
    
    // 골드 보상 색상 계산 - 비활성화 상태 고려
    private func getGoldRewardColor() -> Color {
        if !isGoldEarner {
            return colorScheme == .dark ? .gray.opacity(0.7) : .gray
        } // 골드 획득 캐릭터가 아니면 회색
        
        if isGoldDisabled && isTopRaid {
            return colorScheme == .dark ? .orange.opacity(0.7) : .orange
        } // 비활성화된 상위 레이드는 주황색
        
        if isTopRaid {
            return colorScheme == .dark ? .orange.opacity(0.9) : .orange
        } // 상위 레이드는 주황색
        
        return colorScheme == .dark ? .gray.opacity(0.7) : .gray // 그 외에는 회색
    }
    
    // 난이도에 따른 색상 반환
    private func getDifficultyColor() -> Color {
        let baseColor: Color
        switch gate.difficulty {
        case "하드":
            baseColor = .red
        case "노말":
            baseColor = .blue
        case "싱글":
            baseColor = .green
        default:
            baseColor = .gray
        }
        
        return colorScheme == .dark ? baseColor.opacity(0.9) : baseColor
    }
    
    // 이 관문을 토글할 수 있는지 확인
    private func canToggleGate() -> Bool {
        // 이미 완료된 상태면 토글 가능 (체크 해제)
        if gate.isCompleted {
            return true
        }
        
        // 완료되지 않은 상태에서는 이전 관문이 모두 완료되어야 토글 가능
        // 1관문이면 항상 토글 가능
        if gate.gate == 0 {
            return true
        }
        
        // 이전 관문들이 모두 완료되었는지 확인
        let previousGates = allGates.filter { $0.gate < gate.gate }
        return !previousGates.contains { !$0.isCompleted }
    }
    
    // 관문 토글
    private func toggleGate() {
        if gate.isCompleted {
            // 체크 해제하는 경우 뒷 관문도 모두 해제
            let laterGates = allGates.filter { $0.gate > gate.gate }
            for laterGate in laterGates {
                laterGate.isCompleted = false
                laterGate.lastCompletedAt = nil
                
                // 더보기 사용 초기화
                laterGate.bonusUsed = false
            }
            
            gate.isCompleted = false
            gate.lastCompletedAt = nil
            
            // 현재 관문의 더보기 사용도 초기화
                    gate.bonusUsed = false
            
        } else {
            // 체크하는 경우 이전 관문도 모두 체크
            let previousGates = allGates.filter { $0.gate < gate.gate }
            for previousGate in previousGates {
                if !previousGate.isCompleted {
                    previousGate.isCompleted = true
                    previousGate.lastCompletedAt = Date()
                }
            }
            
            gate.isCompleted = true
            gate.lastCompletedAt = Date()
        }
        
        // 동기화 플래그 설정
        DataSyncManager.shared.markLocalChanges()
        
        // 이벤트 로깅
        Analytics.logEvent("raid_gate_toggled", parameters: [
            "raid_name": gate.raid,
            "gate_number": gate.gate + 1,
            "difficulty": gate.difficulty,
            "is_completed": gate.isCompleted
        ])
    }
    
    // 배경색 결정 - 다크모드 대응
    private func getBackgroundColor() -> Color {
        if !canToggleGate() && !gate.isCompleted {
            return colorScheme == .dark ? Color.gray.opacity(0.08) : Color.gray.opacity(0.05)
        } else if gate.isCompleted {
            return colorScheme == .dark ? Color.gray.opacity(0.15) : Color.gray.opacity(0.1)
        } else {
            return colorScheme == .dark ? Color.cardBackground : Color.white
        }
    }
    
    // 테두리 색상 결정 - 다크모드 대응
    private func getBorderColor() -> Color {
        if !canToggleGate() && !gate.isCompleted {
            return Color.gray.opacity(colorScheme == .dark ? 0.3 : 0.2)  // 비활성화 상태
        } else if gate.isCompleted {
            return Color.gray.opacity(colorScheme == .dark ? 0.5 : 0.3)
        } else {
            // 난이도에 따른 테두리 색상 - 다크모드에서 더 잘 보이도록 투명도 조정
            let color: Color
            switch gate.difficulty {
            case "하드":
                color = .red
            case "노말":
                color = .blue
            case "싱글":
                color = .green
            default:
                color = .gray
            }
            
            return color.opacity(colorScheme == .dark ? 0.5 : 0.3)
        }
    }
}
