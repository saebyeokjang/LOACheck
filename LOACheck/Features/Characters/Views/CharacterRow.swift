//
//  CharacterRow.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 3/21/25.
//

import SwiftUI
import SwiftData

struct CharacterRow: View {
    @Bindable var character: CharacterModel
    let maxGoldEarners: Int
    let goldEarnerCount: Int
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                // 캐릭터 이름 및 기본 정보
                VStack(alignment: .leading, spacing: 4) {
                    Text(character.name)
                        .font(.headline)
                        .foregroundColor(Color.textPrimary)
                    
                    Text("\(character.server) • \(character.characterClass)")
                        .font(.caption)
                        .foregroundColor(Color.textSecondary)
                    
                    Text("레벨: \(String(format: "%.2f", character.level))")
                        .font(.caption)
                        .foregroundColor(Color.textSecondary)
                }
                
                Spacer()
                
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Text("보기")
                            .font(.caption)
                            .foregroundColor(Color.textSecondary)
                            .frame(width: 40, alignment: .trailing)
                        
                        Toggle(isOn: Binding(
                            get: { !character.isHidden },
                            set: { newValue in
                                character.isHidden = !newValue
                                // 동기화 표시 - 토글 변경 시 추가
                                DataSyncManager.shared.markLocalChanges()
                                
                                // 변경 알림 발송
                                DispatchQueue.main.async {
                                    NotificationCenter.default.post(name: NSNotification.Name("RefreshCharacterList"), object: nil)
                                }
                            }
                        )) {
                            Text("")
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                        .labelsHidden()
                    }
                    
                    // 골드 획득 설정
                    HStack(spacing: 8) {
                        Text("골드")
                            .font(.caption)
                            .foregroundColor(Color.textSecondary)
                            .frame(width: 40, alignment: .trailing)
                        
                        Toggle(isOn: Binding(
                            get: { character.isGoldEarner },
                            set: { newValue in
                                if newValue && goldEarnerCount >= maxGoldEarners && !character.isGoldEarner {
                                    // 최대 개수 초과 시 토글 무시
                                    return
                                }
                                character.isGoldEarner = newValue
                                // 동기화 표시 - 토글 변경 시 추가
                                DataSyncManager.shared.markLocalChanges()
                            }
                        )) {
                            Text("")
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .yellow))
                        .labelsHidden()
                        .disabled(goldEarnerCount >= maxGoldEarners && !character.isGoldEarner)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
