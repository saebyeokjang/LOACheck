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
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        // baseGold 변수를 body 메서드 시작 부분에서 계산
        let baseGold = calculateBaseGold()
        
        // 상위 3개 레이드인지 확인
        let isTopRaid = isTopThreeRaid()
        
        NavigationView {
            Form {
                Section(header: Text("\(raidName) 추가 수익")) {
                    HStack {
                        Text("기본 레이드 보상")
                            .font(.headline)
                        
                        Spacer()
                        
                        // 미리 계산된 baseGold 사용 (상위 3개 레이드인 경우만 주황색)
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
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                            
                            Text("G")
                                .foregroundColor(.green)
                        }
                        .padding(6)
                        .background(Color.green.opacity(0.1))
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
                
                Section(footer: Text("클리어 시 획득한 아이템이나 골드 등 추가 수익을 입력하세요.")) {
                    EmptyView()
                }
            }
            .navigationTitle("추가 골드 수익")
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
                        dismiss()
                    }
                }
            }
            .onAppear {
                // 초기 값 설정
                additionalGold = "\(character.getAdditionalGold(for: raidName))"
            }
        }
    }
    
    // 해당 레이드의 기본 골드 보상 계산
    private func calculateBaseGold() -> Int {
        guard let gates = character.raidGates else { return 0 }
        
        // 해당 레이드의 완료된 관문 골드 합산
        let raidGates = gates.filter { $0.raid == raidName && $0.isCompleted }
        return raidGates.reduce(0) { $0 + $1.goldReward }
    }
    
    // 현재 레이드가 상위 3개 레이드인지 확인
    private func isTopThreeRaid() -> Bool {
        let topRaidNames = character.getTopRaidNames()
        return topRaidNames.contains(raidName)
    }
    
    // 입력된 추가 골드 저장
    private func saveAdditionalGold() {
        if let gold = Int(additionalGold) {
            character.setAdditionalGold(gold, for: raidName)
            DataSyncManager.shared.markLocalChanges()
        }
    }
}
