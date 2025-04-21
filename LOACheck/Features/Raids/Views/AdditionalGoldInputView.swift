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
    @Environment(\.dismiss) private var dismiss
    
    init(character: CharacterModel, raidName: String) {
        self.character = character
        self.raidName = raidName
        self._additionalGold = State(initialValue: "\(character.getAdditionalGold(for: raidName))")
    }
    
    var body: some View {
        NavigationView {
            Form {
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
                    }
                }
            }
            .onAppear {
                // 뷰가 나타날 때 한 번만 계산
                calculateDisplayValues()
            }
        }
    }
    
    // 표시 값을 미리 계산
    private func calculateDisplayValues() {
        // 1. 표시용 기본 골드 계산
        if let gates = character.raidGates {
            let raidGates = gates.filter { $0.raid == raidName && $0.isCompleted }
            baseGold = raidGates.reduce(0) { $0 + $1.currentGoldReward }
        }
        
        // 2. 상위 레이드 여부 확인
        let topRaidNames = character.getTopRaidNames()
        isTopRaid = topRaidNames.contains(raidName)
    }
    
    // 입력된 추가 골드 저장 - 안전하게 수정
    private func saveAdditionalGold() {
        // 숫자가 아닌 문자를 안전하게 처리
        let safeGold = Int(additionalGold) ?? 0
        
        // 직접 additionalGoldForRaids 수정 (더 안전한 접근 방식)
        var currentMap = character.additionalGoldForRaids
        currentMap[raidName] = safeGold
        character.additionalGoldForRaids = currentMap
        
        // 동기화 표시
        DataSyncManager.shared.markLocalChanges()
        
        // 서버에 즉시 동기화 시도 추가
        if AuthManager.shared.isLoggedIn && NetworkMonitorService.shared.isConnected {
            Task {
                await DataSyncManager.shared.uploadToServer()
            }
        }
        
        // 대화상자 닫기
        dismiss()
    }
}
