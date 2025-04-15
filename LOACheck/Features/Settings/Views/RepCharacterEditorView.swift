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
    @State private var isProcessing = false
    @State private var errorMessage: String? = nil
    
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
                        .disabled(isProcessing)
                    }
                }
                
                // 직접 입력 옵션
                VStack(spacing: 12) {
                    Divider()
                    
                    TextField("직접 캐릭터 이름 입력", text: $manualRepCharName)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }
                    
                    Button(action: {
                        if !manualRepCharName.isEmpty {
                            setRepresentativeCharacter(manualRepCharName)
                        }
                    }) {
                        HStack {
                            Text("설정하기")
                            if isProcessing {
                                ProgressView()
                                    .padding(.leading, 8)
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(manualRepCharName.isEmpty || isProcessing)
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
    
    // 대표 캐릭터 설정 - 비동기 처리로 개선
    private func setRepresentativeCharacter(_ name: String) {
        isProcessing = true
        errorMessage = nil
        
        Task {
            do {
                // 올바른 비동기 메서드 호출로 변경
                let success = try await authManager.setRepresentativeCharacterAsync(characterName: name)
                
                await MainActor.run {
                    isProcessing = false
                    
                    if success {
                        alertMessage = "대표 캐릭터가 '\(name)'(으)로 설정되었습니다."
                        isShowingAlert = true
                        showRepCharacterEditor = false
                    } else {
                        errorMessage = "'\(name)'은(는) 이미 다른 사용자가 사용 중인 이름입니다."
                    }
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = "오류가 발생했습니다: \(error.localizedDescription)"
                }
            }
        }
    }
}
