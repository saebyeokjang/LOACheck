//
//  RepCharacterEditorView.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 4/11/25.
//

import SwiftUI

struct RepCharacterEditorView: View {
    var characters: [CharacterModel]
    var authManager: AuthManager
    @Binding var showRepCharacterEditor: Bool
    @Binding var alertMessage: String
    @Binding var isShowingAlert: Bool
    @State private var isProcessing = false
    
    var body: some View {
        NavigationStack {
            VStack {
                if characters.isEmpty {
                    Text("캐릭터 정보가 없습니다.\n먼저 API 키를 설정하고 캐릭터를 불러와주세요.")
                        .multilineTextAlignment(.center)
                        .padding()
                } else {
                    List(characters) { character in
                        Button(action: {
                            setRepresentativeCharacter(character)
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(character.name)
                                        .foregroundColor(.primary)
                                    
                                    Text("\(character.server) • \(character.characterClass)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if character.name == authManager.representativeCharacter {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .disabled(isProcessing)
                    }
                }
            }
            .navigationTitle("대표 캐릭터 설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        showRepCharacterEditor = false
                    }
                }
            }
        }
    }
    
    // 대표 캐릭터 설정 - 캐릭터 모델 직접 전달
    private func setRepresentativeCharacter(_ character: CharacterModel) {
        isProcessing = true
        
        // 즉시 UI 업데이트를 위해 로컬 상태 먼저 변경
        let oldCharacterName = authManager.representativeCharacter
        authManager.representativeCharacter = character.name
        
        Task {
            do {
                // 서버에 저장 시도 (캐릭터 모델과 함께)
                let success = try await authManager.setRepresentativeCharacterWithDetails(
                    characterName: character.name,
                    server: character.server,
                    characterClass: character.characterClass,
                    level: character.level
                )
                
                await MainActor.run {
                    isProcessing = false
                    
                    if success {
                        alertMessage = "대표 캐릭터가 '\(character.name)'(으)로 설정되었습니다."
                        isShowingAlert = true
                        showRepCharacterEditor = false
                    } else {
                        // 실패 시 이전 값으로 되돌림
                        authManager.representativeCharacter = oldCharacterName
                        alertMessage = "'\(character.name)'은(는) 이미 다른 사용자가 사용 중인 이름입니다."
                        isShowingAlert = true
                    }
                }
            } catch {
                await MainActor.run {
                    // 실패 시 이전 값으로 되돌림
                    authManager.representativeCharacter = oldCharacterName
                    isProcessing = false
                    alertMessage = "오류가 발생했습니다: \(error.localizedDescription)"
                    isShowingAlert = true
                }
            }
        }
    }
}
