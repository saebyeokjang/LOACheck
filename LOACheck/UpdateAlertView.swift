//
//  UpdateAlertView.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 3/25/25.
//

import SwiftUI

struct UpdateAlertView: View {
    @Binding var isPresented: Bool
    var currentVersion: String
    var latestVersion: String
    var releaseNotes: String?
    var onUpdate: () -> Void
    var onLater: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // 헤더
            VStack(spacing: 8) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.blue)
                
                Text("업데이트가 있습니다")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("LOA Check \(latestVersion) 버전이 출시되었습니다")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text("현재 버전: \(currentVersion)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top)
            
            // 릴리즈 노트
            if let notes = releaseNotes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("업데이트 내용")
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    ScrollView {
                        Text(notes)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxHeight: 100)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            
            // 버튼
            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    Button(action: {
                        onLater()
                        isPresented = false
                    }) {
                        Text("나중에")
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(.primary)
                            .cornerRadius(8)
                    }
                    
                    Button(action: {
                        onUpdate()
                        isPresented = false
                    }) {
                        Text("업데이트")
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                
                // 이 버전 건너뛰기 버튼
                Button(action: {
                    // 현재 버전을 스킵하도록 skipVersion 업데이트
                    UserDefaults.standard.set(latestVersion, forKey: "skipVersion")
                    isPresented = false
                }) {
                    Text("이 버전 업데이트 건너뛰기")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .frame(width: 300)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 20)
    }
}
