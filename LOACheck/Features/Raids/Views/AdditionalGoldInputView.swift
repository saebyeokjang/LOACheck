//
//  AdditionalGoldInputView.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 4/7/25.
//

import SwiftUI
import SwiftData

struct AdditionalGoldInputView: View {
    @Bindable var character: CharacterModel
    var raidName: String
    
    @State private var additionalGold: String = "0"
    @State private var baseGold: Int = 0
    @State private var isTopRaid: Bool = false
    @State private var completedGates: [RaidGate] = []
    @State private var totalBonusCost: Int = 0
    @State private var showConfirmDialog = false
    @State private var gateToToggle: RaidGate?
    @State private var newBonusState = false
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    init(character: CharacterModel, raidName: String) {
        self.character = character
        self.raidName = raidName
        self._additionalGold = State(initialValue: "\(character.getAdditionalGold(for: raidName))")
    }
    
    var body: some View {
        NavigationView {
            Form {
                // 기존 추가 수익 섹션
                Section(header: Text("\(raidName) 추가 수익")) {
                    HStack {
                        Text("기본 레이드 보상")
                            .font(.headline)
                        
                        Spacer()
                        
                        Text("\(baseGold)G")
                            .foregroundColor(isTopRaid ? .orange : .gray)
                    }
                    
                    HStack {
                        Text("추가 수익")
                            .font(.headline)
                        
                        Spacer()
                        
                        // 추가 골드 입력 필드
                        HStack {
                            Text("+")
                                .foregroundColor(.green)
                            
                            TextField("0", text: $additionalGold)
                                .keyboardType(.numberPad)
                                .onChange(of: additionalGold) { _, newValue in
                                    // 숫자만 허용하는 필터링
                                    let filtered = newValue.filter { "0123456789".contains($0) }
                                    if filtered != newValue {
                                        additionalGold = filtered
                                    }
                                }
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                            
                            Text("G")
                                .foregroundColor(.green)
                        }
                        .padding(6)
                        .background(colorScheme == .dark ? Color.green.opacity(0.15) : Color.green.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    HStack {
                        Text("합계")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        // 합계 계산 (상위 3개 레이드가 아니면 추가 수익만 표시)
                        let addGold = Int(additionalGold) ?? 0
                        let totalGold = isTopRaid ? (baseGold + addGold) : addGold
                        Text("\(totalGold)G")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                }
                
                // 새로 추가된 더보기 섹션
                if !completedGates.isEmpty {
                    Section(header: Text("더보기 설정")) {
                        ForEach(completedGates) { gate in
                            let bonusCost = RaidData.getBonusLootCost(raid: raidName, difficulty: gate.difficulty, gate: gate.gate)
                            
                            if bonusCost > 0 { // 더보기 비용이 있는 경우만 표시
                                HStack {
                                    Text("\(gate.gate + 1)관문 더보기")
                                        .font(.subheadline)
                                    
                                    Spacer()
                                    
                                    // 더보기 비용 표시
                                    Text("-\(bonusCost)G")
                                        .foregroundColor(.orange)
                                        .font(.caption)
                                    
                                    // 더보기 토글
                                    Toggle("", isOn: Binding(
                                        get: { gate.bonusUsed },
                                        set: { newValue in
                                            gateToToggle = gate
                                            newBonusState = newValue
                                            
                                            if newValue == true { // 더보기 활성화 시에만 확인 다이얼로그
                                                showConfirmDialog = true
                                            } else { // 더보기 비활성화는 바로 적용
                                                gate.bonusUsed = false
                                                calculateTotalBonusCost()
                                                DataSyncManager.shared.markLocalChanges()
                                            }
                                        }
                                    ))
                                    .labelsHidden()
                                }
                            }
                        }
                        
                        // 총 더보기 비용
                        if totalBonusCost > 0 {
                            HStack {
                                Text("더보기 총 비용")
                                    .font(.headline)
                                
                                Spacer()
                                
                                Text("-\(totalBonusCost)G")
                                    .foregroundColor(.orange)
                                    .font(.headline)
                            }
                            .padding(.top, 4)
                        }
                    }
                }
                
                // 최종 수익 계산 섹션
                Section(header: Text("최종 골드 계산")) {
                    HStack {
                        Text("추가 수익")
                            .foregroundColor(.green)
                        
                        Spacer()
                        
                        Text("+\(Int(additionalGold) ?? 0)G")
                            .foregroundColor(.green)
                    }
                    
                    if totalBonusCost > 0 {
                        HStack {
                            Text("더보기 비용")
                                .foregroundColor(.orange)
                            
                            Spacer()
                            
                            Text("-\(totalBonusCost)G")
                                .foregroundColor(.orange)
                        }
                    }
                    
                    Divider()
                    
                    HStack {
                        Text("최종 순수익")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        let netProfit = (Int(additionalGold) ?? 0) - totalBonusCost
                        Text("\(netProfit)G")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(netProfit >= 0 ? .blue : .red)
                    }
                }
                
                Section(footer: Text("더보기 사용 시 지정된 골드가 소모됩니다. 더보기 설정은 되돌릴 수 없으며, 소모된 골드는 주간 수익에서 차감됩니다.")) {
                    EmptyView()
                }
            }
            .navigationTitle("레이드 골드 관리")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        saveAdditionalGold()
                    }
                }
            }
            .onAppear {
                // 뷰가 나타날 때 데이터 로드
                calculateDisplayValues()
                loadCompletedGates()
                calculateTotalBonusCost()
            }
            .alert("더보기 골드 소모", isPresented: $showConfirmDialog) {
                Button("취소", role: .cancel) { }
                Button("확인", role: .destructive) {
                    if let gate = gateToToggle {
                        gate.bonusUsed = newBonusState
                        calculateTotalBonusCost()
                        DataSyncManager.shared.markLocalChanges()
                    }
                }
            } message: {
                if let gate = gateToToggle {
                    let cost = RaidData.getBonusLootCost(raid: raidName, difficulty: gate.difficulty, gate: gate.gate)
                    Text("\(raidName) \(gate.gate + 1)관문 더보기를 사용하시겠습니까? \(cost)G가 소모됩니다.\n\n더보기는 취소할 수 없으며, 소모된 골드는 주간 획득 골드에서 차감됩니다.")
                } else {
                    Text("더보기를 사용하시겠습니까?")
                }
            }
        }
    }
    
    // 표시 값 계산
    private func calculateDisplayValues() {
        // 표시용 기본 골드 계산
        if let gates = character.raidGates {
            let raidGates = gates.filter { $0.raid == raidName }
            baseGold = raidGates.reduce(0) { $0 + $1.currentGoldReward }
        }
        
        // 상위 레이드 여부 확인
        let topRaidNames = character.getTopRaidNames()
        isTopRaid = topRaidNames.contains(raidName)
    }
    
    // 완료된 관문 로드
    private func loadCompletedGates() {
        if let gates = character.raidGates {
            completedGates = gates.filter { $0.raid == raidName && $0.isCompleted }
        }
    }
    
    // 총 더보기 비용 계산
    private func calculateTotalBonusCost() {
        totalBonusCost = completedGates.filter { $0.bonusUsed }.reduce(0) { total, gate in
            total + RaidData.getBonusLootCost(raid: raidName, difficulty: gate.difficulty, gate: gate.gate)
        }
    }
    
    // 추가 골드 저장
    private func saveAdditionalGold() {
        // 숫자가 아닌 문자를 안전하게 처리
        let safeGold = Int(additionalGold) ?? 0
        
        // 캐릭터 모델에 추가 골드 설정
        character.setAdditionalGold(safeGold, for: raidName)
        
        // 동기화 표시
        DataSyncManager.shared.markLocalChanges()
        
        // 서버 동기화
        if AuthManager.shared.isLoggedIn && NetworkMonitorService.shared.isConnected {
            Task {
                let result = await DataSyncManager.shared.uploadToServer()
                Logger.debug("추가 골드 및 더보기 설정으로 인한 동기화 결과: \(result ? "성공" : "실패")")
            }
        }
        
        dismiss()
    }
}
