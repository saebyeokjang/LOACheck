//
//  AccountSectionView.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 4/11/25.
//

import SwiftUI

struct AccountSectionView: View {
    @EnvironmentObject var authManager: AuthManager
    @Binding var showSignIn: Bool
    @Binding var showSignOut: Bool
    @Binding var showRepCharacterEditor: Bool
    
    var body: some View {
        Section(header: Text("계정")) {
            if authManager.isLoggedIn {
                // 로그인 상태
                HStack {
                    Text("로그인 상태")
                    Spacer()
                    Text("온라인")
                        .foregroundColor(.green)
                }
                
                // 계정 정보
                HStack {
                    Text("계정")
                    Spacer()
                    Text(authManager.email)
                        .foregroundColor(.secondary)
                }
                
                // 대표 캐릭터 정보
                Button(action: {
                    showRepCharacterEditor = true
                }) {
                    HStack {
                        Text("대표 캐릭터")
                        Spacer()
                        Text(authManager.representativeCharacter.isEmpty ? "설정하기" : authManager.representativeCharacter)
                            .foregroundColor(authManager.representativeCharacter.isEmpty ? .orange : .blue)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                // 네트워크 상태
                HStack {
                    Text("네트워크")
                    Spacer()
                    NetworkStatusIndicatorView()
                }
                
                // 로그아웃 버튼
                Button(action: {
                    showSignOut = true
                }) {
                    Text("로그아웃")
                        .foregroundColor(.red)
                }
            } else {
                // 비로그인 상태
                HStack {
                    Text("로그인 상태")
                    Spacer()
                    Text("로그인하지 않음")
                        .foregroundColor(.secondary)
                }
                
                // 로그인 버튼
                Button(action: {
                    showSignIn = true
                }) {
                    Text("로그인")
                        .foregroundColor(.blue)
                }
                
                Text("로그인하면 친구와 진행 상황을 공유할 수 있습니다")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    AccountSectionView(
        showSignIn: .constant(false),
        showSignOut: .constant(false),
        showRepCharacterEditor: .constant(false)
    )
    .environmentObject(AuthManager.shared)
}
