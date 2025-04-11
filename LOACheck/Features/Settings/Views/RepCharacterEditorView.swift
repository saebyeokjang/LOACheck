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
    @State private var manualRepCharName: String = ""
    
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
                            setRepresentativeCharacter(character.name)
                            showRepCharacterEditor = false
                        }) {
                            HStack {
                                Text(character.name)
                                Spacer()
                                if character.name == authManager.representativeCharacter {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
                
                // 직접 입력 옵션
                VStack(spacing: 12) {
                    Divider()
                    
                    TextField("직접 캐릭터 이름 입력", text: $manualRepCharName)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    
                    Button("설정하기") {
                        if !manualRepCharName.isEmpty {
                            setRepresentativeCharacter(manualRepCharName)
                            showRepCharacterEditor = false
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(manualRepCharName.isEmpty)
                }
                .padding()
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
    
    // 대표 캐릭터 설정
    private func setRepresentativeCharacter(_ name: String) {
        authManager.setRepresentativeCharacter(name)
        alertMessage = "대표 캐릭터가 '\(name)'(으)로 설정되었습니다."
        isShowingAlert = true
    }
}

// 미리보기를 위한 기본 설정
#Preview {
    RepCharacterEditorView(
        characters: [],
        authManager: AuthManager.shared,
        showRepCharacterEditor: .constant(true),
        alertMessage: .constant(""),
        isShowingAlert: .constant(false)
    )
}
