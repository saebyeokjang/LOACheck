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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                // 캐릭터 이름 및 기본 정보
                VStack(alignment: .leading, spacing: 4) {
                    Text(character.name)
                        .font(.headline)
                    
                    Text("\(character.server) • \(character.characterClass)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("레벨: \(String(format: "%.2f", character.level))")
                        .font(.caption)
                }
                
                Spacer()
                
                // 설정 버튼들 - 토글 레이블을 왼쪽에 배치
                VStack(spacing: 8) {
                    // 숨김 설정 -> "보기" 기능으로 변경 (토글 off면 숨김 처리)
                    HStack(spacing: 8) {
                        Text("보기")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 40, alignment: .trailing)
                        
                        Toggle(isOn: Binding(
                            get: { !character.isHidden },  // 반전: 토글 on -> 보기 (isHidden = false)
                            set: { newValue in
                                character.isHidden = !newValue  // 반전: 토글 off -> 숨김 (isHidden = true)
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
                            .foregroundColor(.secondary)
                            .frame(width: 40, alignment: .trailing)
                        
                        Toggle(isOn: Binding(
                            get: { character.isGoldEarner },
                            set: { newValue in
                                if newValue && goldEarnerCount >= maxGoldEarners && !character.isGoldEarner {
                                    // 최대 개수 초과 시 토글 무시
                                    return
                                }
                                character.isGoldEarner = newValue
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
