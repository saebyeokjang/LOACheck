//
//  APIKeySectionView.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 4/11/25.
//

import SwiftUI

struct APIKeySectionView: View {
    @Binding var apiKey: String
    @State private var tempApiKey: String = ""
    @FocusState private var isApiKeyFocused: Bool
    @Binding var alertMessage: String
    @Binding var isShowingAlert: Bool
    @State private var isRefreshing = false
    
    var body: some View {
        Section(header: Text("로스트아크 API 설정"), footer: Text("API키 발급받으러 가기\nhttps://developer-lostark.game.onstove.com")) {
            SecureField("API 키 입력", text: $tempApiKey)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($isApiKeyFocused)
                .onAppear {
                    tempApiKey = apiKey
                }
            
            Button(action: {
                // API 키 저장
                apiKey = tempApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                isApiKeyFocused = false
                
                alertMessage = "API 키가 저장되었습니다."
                isShowingAlert = true
            }) {
                Text("API 키 저장")
            }
            .disabled(tempApiKey.isEmpty || isRefreshing)
        }
    }
}

#Preview {
    APIKeySectionView(
        apiKey: .constant(""),
        alertMessage: .constant(""),
        isShowingAlert: .constant(false)
    )
}
