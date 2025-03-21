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
    @State private var gateSettings: [String: [Int: String]] = [:]  // [레이드: [관문번호: 난이도]]
    
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
                            gateSettings: $gateSettings
                        )
                    }
                    
                    Text("캐릭터당 최대 3개의 레이드에서만 골드를 획득할 수 있습니다.\n골드 보상이 높은 레이드부터 우선적으로 적용됩니다.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.bottom, 30)
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
        }
    }
    
    // 현재 설정된 레이드 로드
    private func loadCurrentRaidSettings() {
        // 기존 설정 초기화
        selectedRaids.removeAll()
        gateSettings.removeAll()
        
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
                        newGates.append(existingGate)
                    } else {
                        // 새 관문 생성
                        let newGate = RaidGate(
                            raid: raidName,
                            gate: gateNumber,
                            difficulty: difficulty,
                            goldReward: goldReward,
                            isCompleted: false
                        )
                        newGates.append(newGate)
                    }
                }
            }
        }
        
        // 캐릭터에 새 관문 목록 설정
        character.raidGates = newGates
    }
}

// 레이드 설정 카드 뷰
struct RaidSettingCardView: View {
    var raidGroup: RaidGroup
    @Binding var selectedRaids: Set<String>
    @Binding var gateSettings: [String: [Int: String]]
    
    @State private var showGateSettings: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 레이드 헤더
            HStack {
                // 레이드 선택 토글
                Toggle(isOn: Binding(
                    get: { selectedRaids.contains(raidGroup.name) },
                    set: { isSelected in
                        if isSelected {
                            selectedRaids.insert(raidGroup.name)
                            initializeGateSettings()
                        } else {
                            selectedRaids.remove(raidGroup.name)
                            gateSettings.removeValue(forKey: raidGroup.name)
                        }
                        showGateSettings = isSelected
                    }
                )) {
                    Text("\(getOrderString(for: raidGroup.name)) \(raidGroup.name)")
                        .font(.headline)
                }
                .toggleStyle(SwitchToggleStyle(tint: .blue))
                
                Spacer()
                
                // 더보기 버튼
                if selectedRaids.contains(raidGroup.name) {
                    Button(action: {
                        withAnimation {
                            showGateSettings.toggle()
                        }
                    }) {
                        Image(systemName: showGateSettings ? "chevron.up" : "chevron.down")
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(10)
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
            
            // 관문 설정 패널
            if selectedRaids.contains(raidGroup.name) && showGateSettings {
                VStack(spacing: 12) {
                    // 각 관문별 난이도 선택
                    ForEach(0..<raidGroup.gateCount, id: \.self) { gateIndex in
                        GateSettingRow(
                            raidName: raidGroup.name,
                            gateIndex: gateIndex,
                            availableDifficulties: raidGroup.availableDifficulties.map { $0.rawValue },
                            gateSettings: $gateSettings
                        )
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(8)
            }
        }
    }
    
    // 레이드 순서 문자열 가져오기
    private func getOrderString(for raidName: String) -> String {
        if raidName.contains("모르둠") { return "3막" }
        if raidName.contains("아브렐슈드") && raidName.contains("2막") { return "2막" }
        if raidName.contains("에기르") { return "1막" }
        return ""
    }
    
    // 기본 관문 설정 초기화
    private func initializeGateSettings() {
        if gateSettings[raidGroup.name] == nil {
            // 기본 난이도 (가장 높은 난이도)
            let highestDifficulty = raidGroup.availableDifficulties.last?.rawValue ?? "노말"
            
            var gateDifficulties: [Int: String] = [:]
            for gate in 0..<raidGroup.gateCount {
                gateDifficulties[gate] = highestDifficulty
            }
            gateSettings[raidGroup.name] = gateDifficulties
        }
    }
}

// 관문 설정 행
struct GateSettingRow: View {
    var raidName: String
    var gateIndex: Int
    var availableDifficulties: [String]
    @Binding var gateSettings: [String: [Int: String]]
    
    var body: some View {
        HStack {
            Text("\(gateIndex + 1)관문")
                .font(.subheadline)
                .frame(width: 60, alignment: .leading)
            
            Spacer()
            
            // 각 난이도별 선택 버튼
            HStack(spacing: 4) {
                ForEach(availableDifficulties, id: \.self) { difficulty in
                    Button(action: {
                        selectDifficulty(difficulty)
                    }) {
                        let isSelected = isSelectedDifficulty(difficulty)
                        
                        Text(difficulty)
                            .font(.caption)
                            .fontWeight(isSelected ? .bold : .regular)
                            .frame(minWidth: 60)
                            .padding(.vertical, 8)
                            .background(isSelected ? getDifficultyColor(difficulty).opacity(0.1) : Color.gray.opacity(0.1))
                            .foregroundColor(isSelected ? getDifficultyColor(difficulty) : .gray)
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(isSelected ? getDifficultyColor(difficulty) : Color.clear, lineWidth: 1)
                            )
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
    
    // 난이도 선택
    private func selectDifficulty(_ difficulty: String) {
        if gateSettings[raidName] == nil {
            gateSettings[raidName] = [:]
        }
        gateSettings[raidName]?[gateIndex] = difficulty
    }
    
    // 선택된 난이도인지 확인
    private func isSelectedDifficulty(_ difficulty: String) -> Bool {
        return gateSettings[raidName]?[gateIndex] == difficulty
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
}
