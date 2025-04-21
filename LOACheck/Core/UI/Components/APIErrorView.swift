//
//  APIErrorView.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 4/2/25.
//

import SwiftUI

// 통일된 에러 화면 컴포넌트
struct APIErrorView: View {
    var message: String
    var retryAction: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text(message)
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding()
                .foregroundColor(Color.textPrimary)
            
            Button(action: retryAction) {
                Text("다시 시도")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(width: 200)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color.backgroundPrimary)
    }
}
