//
//  CharacterDetailView.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 3/20/25.
//

import SwiftUI
import SwiftData

struct CharacterDetailView: View {
    var character: CharacterModel
    var isCurrentlyActive: Bool = true // 현재 활성화된 페이지인지 여부
    @State private var scrollViewID = UUID() // 페이지 전환 시 스크롤뷰 재설정용 ID
    
    // 스크롤 위치 추적을 위한 네임스페이스
    private enum ScrollToTop {
        case top
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) { // 스크롤바 숨김
                VStack(spacing: 16) {
                    // 스크롤 최상단 위치 식별을 위한 빈 뷰
                    Color.clear
                        .frame(height: 0)
                        .id(ScrollToTop.top)
                    
                    // 캐릭터 정보 헤더
                    CharacterHeaderView(character: character)
                    
                    // 일일 숙제 섹션
                    if let dailyTasks = character.dailyTasks, !dailyTasks.isEmpty {
                        DailyTasksView(
                            tasks: dailyTasks,
                            character: character,  // 캐릭터 모델 전달
                            isActiveView: isCurrentlyActive
                        )
                    }
                    
                    // 주간 레이드 섹션
                    WeeklyRaidsView(character: character)
                    
                    Spacer()
                }
                .padding(.bottom, 20)
            }
            .id(scrollViewID) // 스크롤뷰 ID 부여
            .onAppear {
                // 뷰가 나타날 때 최상단으로 이동
                proxy.scrollTo(ScrollToTop.top, anchor: .top)
            }
            .onChange(of: isCurrentlyActive) { _, newValue in
                if newValue {
                    // 페이지가 활성화될 때 스크롤 위치 재설정
                    scrollViewID = UUID() // 스크롤뷰 재생성
                    DispatchQueue.main.async {
                        proxy.scrollTo(ScrollToTop.top, anchor: .top)
                    }
                }
            }
        }
    }
}

// 캐릭터 헤더 뷰 추가
struct CharacterHeaderView: View {
    var character: CharacterModel
    
    var body: some View {
        VStack(spacing: 12) {
            // 캐릭터 이름 및 정보
            Text(character.name)
                .font(.title)
                .fontWeight(.bold)
            
            Text("\(character.server) • \(character.characterClass)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("아이템 레벨: \(String(format: "%.2f", character.level))")
                .font(.headline)
                .padding(.vertical, 4)
                .padding(.horizontal, 12)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            
            // 골드 획득 캐릭터 표시
            if character.isGoldEarner {
                Text("골드 획득 캐릭터")
                    .font(.caption)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(Color.yellow.opacity(0.2))
                    .foregroundColor(.orange)
                    .cornerRadius(4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}
