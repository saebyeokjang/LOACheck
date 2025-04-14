//
//  RaidSettingsView.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 3/21/25.
//

import SwiftUI
import SwiftData

struct RaidSettingsView: View {
    var character: CharacterModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    // 각 레이드별 설정을 저장할 상태 변수
    @State private var selectedRaids: Set<String> = []
    @State private var gateSettings: [String: [Int: String]] = [:]
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var goldDisabledRaids: Set<String> = []
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 레이드 데이터를 레벨 기준 내림차순으로 가져오기
                    let availableRaidGroups = character.getAvailableRaidGroups()
                    
                    ForEach(availableRaidGroups) { raidGroup in
                        RaidSettingCardView(
                            raidGroup: raidGroup,
                            selectedRaids: $selectedRaids,
                            gateSettings: $gateSettings,
                            showAlert: $showAlert,
                            alertMessage: $alertMessage,
                            goldDisabledRaids: $goldDisabledRaids
                        )
                    }
                    
                    Text("캐릭터당 최대 3개의 레이드에서만 골드를 획득할 수 있습니다.\n골드 보상이 높은 레이드부터 우선적으로 적용됩니다.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.bottom, 30)
                    
                    // 골드 비활성화 안내문 추가
                    if !goldDisabledRaids.isEmpty {
                        Text("골드 비활성화된 레이드: \(goldDisabledRaids.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .padding(.bottom, 10)
                    }
                }
                .padding()
            }
            .navigationTitle("레이드 설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        saveRaidSettings()
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadCurrentRaidSettings()
            }
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("알림"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("확인"))
                )
            }
        }
    }
    
    // 현재 설정된 레이드 로드
    private func loadCurrentRaidSettings() {
        // 기존 설정 초기화
        selectedRaids.removeAll()
        gateSettings.removeAll()
        goldDisabledRaids.removeAll()
        
        if let gates = character.raidGates {
            // 레이드별로 관문 설정 그룹화
            let groupedGates = Dictionary(grouping: gates) { $0.raid }
            
            for (raid, gates) in groupedGates {
                // 레이드 선택
                selectedRaids.insert(raid)
                
                // 관문별 난이도 설정
                var raidGateSettings: [Int: String] = [:]
                for gate in gates {
                    raidGateSettings[gate.gate] = gate.difficulty
                }
                
                gateSettings[raid] = raidGateSettings
                
                // 골드 비활성화 설정 로드
                if let firstGate = gates.first, firstGate.isGoldDisabled {
                    goldDisabledRaids.insert(raid)
                }
            }
        }
    }
    
    // 선택된 레이드 설정 저장
    private func saveRaidSettings() {
        // 기존 레이드 관문 정보 저장
        var existingGates: [String: RaidGate] = [:]
        if let gates = character.raidGates {
            for gate in gates {
                let key = "\(gate.raid)-\(gate.gate)-\(gate.difficulty)"
                existingGates[key] = gate
            }
        }
        
        // 새 레이드 관문 목록 생성
        var newGates: [RaidGate] = []
        
        for raidName in selectedRaids {
            if let raidGateSettings = gateSettings[raidName] {
                let isGoldDisabled = goldDisabledRaids.contains(raidName)
                
                for (gateNumber, difficulty) in raidGateSettings {
                    // 골드 보상 가져오기
                    let goldReward = RaidData.getGoldReward(
                        raid: raidName,
                        difficulty: difficulty,
                        gate: gateNumber
                    )
                    
                    // 관문 키 생성
                    let key = "\(raidName)-\(gateNumber)-\(difficulty)"
                    
                    if let existingGate = existingGates[key] {
                        // 기존 관문 업데이트
                        existingGate.goldReward = goldReward
                        existingGate.isGoldDisabled = isGoldDisabled // 골드 비활성화 상태 업데이트
                        newGates.append(existingGate)
                    } else {
                        // 새 관문 생성
                        let newGate = RaidGate(
                            raid: raidName,
                            gate: gateNumber,
                            difficulty: difficulty,
                            goldReward: goldReward,
                            isCompleted: false,
                            lastCompletedAt: nil,
                            isGoldDisabled: isGoldDisabled // 골드 비활성화 상태 설정
                        )
                        newGates.append(newGate)
                    }
                }
            }
        }
        
        // 캐릭터에 새 관문 목록 설정
        character.raidGates = newGates
        
        // 동기화 표시
        DataSyncManager.shared.markLocalChanges()
    }
}

// 레이드 설정 카드 뷰
struct RaidSettingCardView: View {
    var raidGroup: RaidGroup
    @Binding var selectedRaids: Set<String>
    @Binding var gateSettings: [String: [Int: String]]
    @Binding var showAlert: Bool
    @Binding var alertMessage: String
    @Binding var goldDisabledRaids: Set<String>
    
    @State private var showGateSettings: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 레이드 헤더 - 새로운 레이아웃
            HStack {
                // 레이드 이름
                Text("\(getOrderString(for: raidGroup.name)) \(raidGroup.name)")
                    .font(.headline)
                
                Spacer()
                
                if selectedRaids.contains(raidGroup.name) {
                    Text("골드")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    // 골드 활성화 토글
                    Toggle("", isOn: Binding(
                        get: { !goldDisabledRaids.contains(raidGroup.name) },
                        set: { isEnabled in
                            if isEnabled {
                                goldDisabledRaids.remove(raidGroup.name)
                            } else {
                                goldDisabledRaids.insert(raidGroup.name)
                            }
                        }
                    ))
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: .orange))
                    .frame(width: 50)
                }
                
                // 레이드 선택 토글
                Toggle("", isOn: Binding(
                    get: { selectedRaids.contains(raidGroup.name) },
                    set: { isSelected in
                        if isSelected {
                            selectedRaids.insert(raidGroup.name)
                            if gateSettings[raidGroup.name] == nil {
                                gateSettings[raidGroup.name] = [:]
                            }
                        } else {
                            selectedRaids.remove(raidGroup.name)
                            gateSettings.removeValue(forKey: raidGroup.name)
                            goldDisabledRaids.remove(raidGroup.name)
                        }
                        showGateSettings = isSelected
                    }
                ))
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: .blue))
                .frame(width: 50)
                
                // 더보기 버튼
                Button(action: {
                    withAnimation {
                        showGateSettings.toggle()
                    }
                }) {
                    Image(systemName: showGateSettings ? "chevron.up" : "chevron.down")
                        .foregroundColor(.gray)
                }
                .buttonStyle(PlainButtonStyle())
                .opacity(selectedRaids.contains(raidGroup.name) ? 1.0 : 0.0)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(10)
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
            
            // 관문 설정 패널
            if selectedRaids.contains(raidGroup.name) && showGateSettings {
                VStack(spacing: 16) {
                    // 난이도별 관문 가로 뷰 (싱글, 노말, 하드 순)
                    let availableDifficulties = raidGroup.availableDifficulties.map { $0.rawValue }
                    
                    ForEach(availableDifficulties, id: \.self) { difficulty in
                        DifficultyRow(
                            raidName: raidGroup.name,
                            difficulty: difficulty,
                            gateCount: getGateCount(for: difficulty),
                            gateSettings: $gateSettings,
                            showAlert: $showAlert,
                            alertMessage: $alertMessage,
                            isGoldDisabled: goldDisabledRaids.contains(raidGroup.name)
                        )
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(8)
            }
        }
    }
    
    private func getOrderString(for raidName: String) -> String {
        if raidName.contains("모르둠") { return "3막" }
        if raidName.contains("아브렐슈드") && raidName.contains("2막") { return "" }
        if raidName.contains("에기르") { return "1막" }
        return ""
    }
    
    private func getGateCount(for difficulty: String) -> Int {
        if raidGroup.name == "카멘" && difficulty != "하드" {
            return 3 // 카멘 싱글/노말은 3관문까지
        }
        return raidGroup.gateCount
    }
}

// 난이도별 관문 행 (가로 레이아웃)
struct DifficultyRow: View {
    var raidName: String
    var difficulty: String
    var gateCount: Int
    @Binding var gateSettings: [String: [Int: String]]
    @Binding var showAlert: Bool
    @Binding var alertMessage: String
    var isGoldDisabled: Bool
    
    // 해당 난이도 선택된 관문 수
    private var selectedGatesCount: Int {
        if let settings = gateSettings[raidName] {
            return settings.filter { $0.value == difficulty }.count
        }
        return 0
    }
    
    // 해당 난이도 총 골드 계산
    private var totalGold: Int {
        if isGoldDisabled {
            return 0
        }
        var total = 0
        for i in 0..<gateCount {
            if isGateSelected(i) {
                total += getGoldReward(i)
            }
        }
        return total
    }
    
    // 싱글 난이도가 선택되었는지 확인
    private var isSingleMode: Bool {
        if let settings = gateSettings[raidName] {
            return settings.values.contains("싱글")
        }
        return false
    }
    
    // 어떤 난이도가 선택되었는지 확인
    private var selectedDifficulty: String? {
        if let settings = gateSettings[raidName], !settings.isEmpty {
            // 0번 관문의 난이도를 기준으로 함
            return settings[0]
        }
        return nil
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // 난이도 및 골드 표시 (첫번째 칸)
            DifficultyHeaderCell(
                difficulty: difficulty,
                totalGold: totalGold,
                isSelected: selectedGatesCount > 0,
                isGoldDisabled: isGoldDisabled,
                onSelect: {
                    selectAllGates()
                }
            )
            
            // 각 관문 셀
            ForEach(0..<gateCount, id: \.self) { gateIndex in
                GateCell(
                    gateIndex: gateIndex,
                    goldReward: getGoldReward(gateIndex),
                    isSelected: isGateSelected(gateIndex),
                    isGoldDisabled: isGoldDisabled,
                    onSelect: {
                        toggleGate(gateIndex)
                    }
                )
            }
        }
        .background(Color.white)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .disabled(shouldDisableRow())
    }
    
    // 해당 행을 비활성화해야 하는지 확인
    private func shouldDisableRow() -> Bool {
        // 싱글 난이도가 선택되어 있고, 현재 행이 싱글이 아니면 비활성화
        if let firstDiff = selectedDifficulty, firstDiff == "싱글" && difficulty != "싱글" {
            return true
        }
        
        // 노말이나 하드가 선택되어 있고, 현재 행이 싱글이면 비활성화
        if let firstDiff = selectedDifficulty, firstDiff != "싱글" && difficulty == "싱글" {
            return true
        }
        
        return false
    }
    
    // 관문 선택 여부 확인
    private func isGateSelected(_ gateIndex: Int) -> Bool {
        if let settings = gateSettings[raidName] {
            return settings[gateIndex] == difficulty
        }
        return false
    }
    
    // 관문 골드 보상 가져오기
    private func getGoldReward(_ gateIndex: Int) -> Int {
        return RaidData.getGoldReward(
            raid: raidName,
            difficulty: difficulty,
            gate: gateIndex
        )
    }
    
    // 이전 관문이 모두 선택되었는지 확인
    private func arePreviousGatesSelected(_ gateIndex: Int) -> Bool {
        // 첫번째 관문은 항상 선택 가능
        if gateIndex == 0 {
            return true
        }
        
        // 이전 관문들 중 하나라도 선택되지 않았으면 false
        for i in 0..<gateIndex {
            if !isAnyDifficultySelected(i) {
                return false
            }
        }
        
        return true
    }
    
    // 상위 관문이 선택되어 있는지 확인
    private func hasLaterGatesSelected(_ gateIndex: Int) -> Bool {
        if let settings = gateSettings[raidName] {
            // 현재 관문 이후의 관문 중 하나라도 선택되어 있으면 true
            for i in (gateIndex + 1)..<getMaxGateCount() {
                if settings[i] != nil {
                    return true
                }
            }
        }
        return false
    }
    
    // 전체 관문 수 가져오기 (모든 난이도 중 최대값)
    private func getMaxGateCount() -> Int {
        if raidName == "카멘" {
            return 4 // 카멘은 최대 4관문
        }
        return gateCount
    }
    
    // 해당 관문이 어떤 난이도로든 선택되었는지 확인
    private func isAnyDifficultySelected(_ gateIndex: Int) -> Bool {
        if let settings = gateSettings[raidName] {
            return settings[gateIndex] != nil
        }
        return false
    }
    
    // 관문 토글
    private func toggleGate(_ gateIndex: Int) {
        if gateSettings[raidName] == nil {
            gateSettings[raidName] = [:]
        }
        
        // 이미 선택된 관문을 해제하려는 경우
        if isGateSelected(gateIndex) {
            // 상위 관문이 선택되어 있는지 확인
            if hasLaterGatesSelected(gateIndex) {
                alertMessage = "상위 관문을 먼저 해제해주세요."
                showAlert = true
                return
            }
            
            // 해당 관문 해제
            gateSettings[raidName]?.removeValue(forKey: gateIndex)
        } else {
            // 새로 선택하는 경우
            
            // 이전 관문이 모두 선택되었는지 확인
            if !arePreviousGatesSelected(gateIndex) {
                alertMessage = "이전 관문의 난이도를 먼저 선택해주세요."
                showAlert = true
                return
            }
            
            // 이미 다른 난이도로 선택되어 있으면 해제 후 변경
            if isAnyDifficultySelected(gateIndex) {
                gateSettings[raidName]?.removeValue(forKey: gateIndex)
            }
            
            // 새로 선택
            gateSettings[raidName]?[gateIndex] = difficulty
            
            // 카멘 레이드 특별 처리
            if raidName == "카멘" {
                // 싱글 난이도 선택 시 4관문 해제
                if difficulty == "싱글" {
                    gateSettings[raidName]?.removeValue(forKey: 3)
                }
                // 4관문은 항상 하드 난이도
                else if gateIndex == 3 {
                    gateSettings[raidName]?[3] = "하드"
                }
            }
        }
    }
    
    // 해당 난이도의 모든 관문 선택
    private func selectAllGates() {
        if gateSettings[raidName] == nil {
            gateSettings[raidName] = [:]
        }
        
        // 이미 모든 관문이 선택되어 있으면 모두 해제
        if selectedGatesCount == gateCount {
            // 해당 난이도로 선택된 모든 관문 해제
            if let settings = gateSettings[raidName] {
                // 이 난이도를 가진 관문의 키(인덱스)들을 찾음
                let keysToRemove = settings.compactMap { (key, value) -> Int? in
                    return value == difficulty ? key : nil
                }
                
                // 찾은 키들에 해당하는 항목 제거 (가장 높은 번호부터 제거)
                for key in keysToRemove.sorted(by: >) {
                    gateSettings[raidName]?.removeValue(forKey: key)
                }
            }
        } else {
            // 먼저 모든 관문 해제
            gateSettings[raidName] = [:]
            
            // 새로 선택
            // 모든 관문 선택
            for i in 0..<gateCount {
                gateSettings[raidName]?[i] = difficulty
            }
            
            // 카멘 레이드 특별 처리
            if raidName == "카멘" {
                if difficulty == "싱글" {
                    // 싱글 난이도는 4관문 제거
                    gateSettings[raidName]?.removeValue(forKey: 3)
                } else if difficulty == "하드" {
                    // 하드 난이도는 4관문 추가
                    gateSettings[raidName]?[3] = "하드"
                }
            }
        }
    }
}

// 난이도 헤더 셀
struct DifficultyHeaderCell: View {
    var difficulty: String
    var totalGold: Int
    var isSelected: Bool
    var isGoldDisabled: Bool
    var onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 4) {
                Text(difficulty)
                    .font(.headline)
                    .foregroundColor(getDifficultyColor())
                
                HStack(spacing: 2) {
                    Text("\(totalGold)G")
                        .font(.caption)
                        .foregroundColor(isGoldDisabled ? .gray : .orange)
                        .strikethrough(isGoldDisabled)
                }
            }
            .frame(height: 60)
            .frame(minWidth: 0, maxWidth: .infinity)
            .background(isSelected ? getDifficultyColor().opacity(0.1) : Color.gray.opacity(0.05))
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // 난이도에 따른 색상 반환
    private func getDifficultyColor() -> Color {
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

// 관문 셀
struct GateCell: View {
    var gateIndex: Int
    var goldReward: Int
    var isSelected: Bool
    var isGoldDisabled: Bool
    var onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 4) {
                Text("\(gateIndex + 1)관문")
                    .font(.caption)
                    .fontWeight(isSelected ? .bold : .regular)
                
                HStack(spacing: 2) {
                    Text("\(goldReward)G")
                        .font(.caption)
                        .foregroundColor(isGoldDisabled ? .gray : .orange)
                        .strikethrough(isGoldDisabled)
                }
            }
            .frame(height: 60)
            .frame(minWidth: 0, maxWidth: .infinity)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.white)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
