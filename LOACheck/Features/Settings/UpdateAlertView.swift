//
//  UpdateAlertView.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 3/25/25.
//

import SwiftUI

/// 앱 업데이트 알림 뷰
struct UpdateAlertView: View {
    @Binding var isPresented: Bool
    var currentVersion: String
    var latestVersion: String
    var releaseNotes: String?
    var onUpdate: () -> Void
    var onLater: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
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
                    .foregroundColor(Color.textPrimary)
                
                Text("LOA Check \(latestVersion) 버전이 출시되었습니다")
                    .font(.headline)
                    .foregroundColor(Color.textSecondary)
                
                Text("현재 버전: \(currentVersion)")
                    .font(.caption)
                    .foregroundColor(Color.textSecondary)
            }
            .padding(.top)
            
            // 릴리즈 노트
            if let notes = releaseNotes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("업데이트 내용")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(Color.textPrimary)
                    
                    ScrollView {
                        Text(notes)
                            .font(.subheadline)
                            .foregroundColor(Color.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxHeight: 100)
                }
                .padding()
                .background(colorScheme == .dark ? Color.gray.opacity(0.15) : Color.gray.opacity(0.1))
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
                            .background(colorScheme == .dark ? Color.gray.opacity(0.3) : Color.gray.opacity(0.2))
                            .foregroundColor(Color.textPrimary)
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
                        .foregroundColor(Color.textSecondary)
                        .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .frame(width: 300)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(radius: colorScheme == .dark ? 20 : 10)
    }
}

// MARK: - 프리뷰
struct UpdateAlertView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // 라이트 모드
            UpdateAlertView(
                isPresented: .constant(true),
                currentVersion: "1.2.0",
                latestVersion: "1.3.0",
                releaseNotes: """
                # 새로운 기능
                - 다크모드 지원 추가
                - 주간 레이드 골드 계산 개선
                - 퍼포먼스 최적화
                
                # 버그 수정
                - 친구 요청 페이지 오류 수정
                - 시세 검색 필터 문제 해결
                """,
                onUpdate: {},
                onLater: {}
            )
            .previewDisplayName("라이트 모드")
            
            // 다크 모드
            UpdateAlertView(
                isPresented: .constant(true),
                currentVersion: "1.2.0",
                latestVersion: "1.3.0",
                releaseNotes: """
                # 새로운 기능
                - 다크모드 지원 추가
                - 주간 레이드 골드 계산 개선
                - 퍼포먼스 최적화
                
                # 버그 수정
                - 친구 요청 페이지 오류 수정
                - 시세 검색 필터 문제 해결
                """,
                onUpdate: {},
                onLater: {}
            )
            .preferredColorScheme(.dark)
            .previewDisplayName("다크 모드")
            
            // 릴리즈 노트 없는 버전
            UpdateAlertView(
                isPresented: .constant(true),
                currentVersion: "1.2.0",
                latestVersion: "1.3.0",
                releaseNotes: nil,
                onUpdate: {},
                onLater: {}
            )
            .previewDisplayName("릴리즈 노트 없음")
        }
    }
}
