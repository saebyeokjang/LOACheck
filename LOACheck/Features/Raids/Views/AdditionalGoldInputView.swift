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
                                .keyboardType(.numberPad)  // 숫자 키패드만 표시
                                .onChange(of: additionalGold) { _, newValue in
                                    // 숫자만 허용하는 정규식 필터 적용
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
                        
                        // 서버에 즉시 동기화 시도 추가
                        if AuthManager.shared.isLoggedIn && NetworkMonitorService.shared.isConnected {
                            Task {
                                await DataSyncManager.shared.uploadToServer()
                            }
                        }
                        
                        dismiss()
                    }
                }
            }
            .onAppear {
                // 현재 additionalGoldMap에서 값을 가져오는 것으로 변경
                additionalGold = "\(character.getAdditionalGold(for: raidName))"
                
                // 로그로 현재 상태 확인
                Logger.debug("레이드 \(raidName)의 additionalGoldMap: \(character.getAdditionalGold(for: raidName))G")
                
                // 해당 레이드의 관문 additionalGold 출력
                if let gates = character.raidGates {
                    let matchingGates = gates.filter { $0.raid == raidName }
                    for gate in matchingGates {
                        Logger.debug("레이드 게이트 \(raidName) 관문 \(gate.gate + 1)의 additionalGold: \(gate.additionalGold)G")
                    }
                }
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
        // 숫자가 아닌 문자를 안전하게 처리
        let safeGold = Int(additionalGold) ?? 0
        
        // CharacterModel의 setAdditionalGold 메서드 호출
        character.setAdditionalGold(safeGold, for: raidName)
        
        // 로그로 설정 후 상태 확인
        Logger.debug("추가 골드 저장 후 additionalGoldMap: \(character.additionalGoldMap)")
        
        if let gates = character.raidGates {
            let matchingGates = gates.filter { $0.raid == raidName }
            for gate in matchingGates {
                Logger.debug("저장 후 레이드 게이트 \(raidName) 관문 \(gate.gate + 1)의 additionalGold: \(gate.additionalGold)G")
            }
        }
        
        // 동기화 표시
        DataSyncManager.shared.markLocalChanges()
    }
}
