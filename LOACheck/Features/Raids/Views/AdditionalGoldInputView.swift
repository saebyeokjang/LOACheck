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
    
    // 입력된 추가 골드 저장
    private func saveAdditionalGold() {
        // 숫자가 아닌 문자를 안전하게 처리
        let safeGold = Int(additionalGold) ?? 0
        
        // 직접 additionalGoldForRaids 수정
        var currentMap = character.additionalGoldForRaids
        currentMap[raidName] = safeGold
        character.additionalGoldForRaids = currentMap
        
        // 개별 RaidGate 객체에도 additionalGold 값 적용
        if let gates = character.raidGates {
            for gate in gates where gate.raid == raidName {
                gate.additionalGold = safeGold
            }
        }
        
        // 중요: modelContext에 직접 접근하여 즉시 저장
        if let modelContext = character.modelContext {
            do {
                try modelContext.save()
                Logger.debug("추가 골드 수정 내용 디스크에 저장 성공")
            } catch {
                Logger.error("추가 골드 저장 실패", error: error)
            }
        }
        
        // 동기화 표시
        DataSyncManager.shared.markLocalChanges()
        
        // 서버 동기화를 위한 Task
        if AuthManager.shared.isLoggedIn && NetworkMonitorService.shared.isConnected {
            Task {
                // 동기화 결과를 기다림
                let result = await DataSyncManager.shared.uploadToServer()
                Logger.debug("추가 골드 수정으로 인한 동기화 결과: \(result ? "성공" : "실패")")
                
                // 성공하지 못했다면 UserDefaults에 임시 백업
                if !result {
                    // 백업 저장 - 앱 재시작 시 복원 가능하도록
                    saveBackupAdditionalGold(raidName: raidName, gold: safeGold, characterId: character.id)
                }
            }
        } else {
            // 오프라인 상태면 UserDefaults에 임시 백업
            saveBackupAdditionalGold(raidName: raidName, gold: safeGold, characterId: character.id)
        }
        
        // 대화상자 닫기
        dismiss()
    }

    // 백업 저장 헬퍼 함수
    private func saveBackupAdditionalGold(raidName: String, gold: Int, characterId: PersistentIdentifier) {
        // 캐릭터 이름을 사용하여 고유 키 생성
        let characterIdString = character.name.replacingOccurrences(of: " ", with: "_")
        let key = "backup_gold_\(characterIdString)_\(raidName)"
        UserDefaults.standard.set(gold, forKey: key)
        Logger.debug("추가 골드 백업 저장: \(raidName) - \(gold)G")
    }
}
