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
    @Environment(\.colorScheme) private var colorScheme
    
    // 페이지 이동 관련 콜백
    var goToPreviousPage: (() -> Void)?
    var goToNextPage: (() -> Void)?
    
    // 스크롤 위치 추적을 위한 네임스페이스
    private enum ScrollToTop {
        case top
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    // 스크롤 최상단 위치 식별을 위한 빈 뷰
                    Color.clear
                        .frame(height: 0)
                        .id(ScrollToTop.top)
                    
                    // 캐릭터 정보 헤더
                    CharacterHeaderView(
                        character: character,
                        goToPreviousPage: goToPreviousPage,
                        goToNextPage: goToNextPage
                    )
                    
                    // 일일 숙제 섹션
                    if let dailyTasks = character.dailyTasks, !dailyTasks.isEmpty {
                        DailyTasksView(
                            tasks: dailyTasks,
                            character: character,
                            isActiveView: isCurrentlyActive
                        )
                    }
                    
                    // 주간 레이드 섹션 - 다크모드 개선 버전 사용
                    WeeklyRaidsView(character: character)
                    
                    Spacer()
                }
                .padding(.bottom, 20)
            }
            .id(scrollViewID)
            .onAppear {
                // 뷰가 나타날 때 최상단으로 이동
                proxy.scrollTo(ScrollToTop.top, anchor: .top)
            }
            .onChange(of: isCurrentlyActive) { _, newValue in
                if newValue {
                    // 페이지가 활성화될 때 스크롤 위치 재설정
                    scrollViewID = UUID()
                    DispatchQueue.main.async {
                        proxy.scrollTo(ScrollToTop.top, anchor: .top)
                    }
                }
            }
            // 배경색을 다크모드 대응 색상으로 변경
            .background(Color.backgroundPrimary)
        }
    }
}

// 캐릭터 헤더 뷰 추가
struct CharacterHeaderView: View {
    var character: CharacterModel
    var goToPreviousPage: (() -> Void)?
    var goToNextPage: (() -> Void)?
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 12) {
            // 페이지 이동 버튼 포함한 캐릭터 헤더
            HStack {
                // 이전 페이지로 이동
                Button(action: {
                    goToPreviousPage?()
                }) {
                    Image(systemName: "chevron.left")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                    // 다크모드에서 더 잘 보이도록 색상 조정
                        .foregroundColor(goToPreviousPage != nil ?
                                         (colorScheme == .dark ? .blue.opacity(0.9) : .blue) :
                                            (colorScheme == .dark ? .gray.opacity(0.7) : .gray))
                        .frame(width: 44, height: 44)
                        .background(Color.clear)
                        .cornerRadius(8)
                }
                .disabled(goToPreviousPage == nil)
                
                Spacer()
                
                VStack(spacing: 8) {
                    // 캐릭터 이름 및 정보
                    Text(character.name)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(Color.textPrimary)
                    
                    Text("\(character.server) • \(character.characterClass)")
                        .font(.subheadline)
                        .foregroundColor(Color.textSecondary)
                    
                    Text("아이템 레벨: \(String(format: "%.2f", character.level))")
                        .font(.headline)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 12)
                    // 다크모드에서 더 잘 보이도록 배경색 조정
                        .background(Color.blue.opacity(colorScheme == .dark ? 0.15 : 0.1))
                    // 다크모드에서 색상 조정
                        .foregroundColor(colorScheme == .dark ? .blue.opacity(0.9) : .blue)
                        .cornerRadius(8)
                    
                    // 골드 획득 캐릭터 표시
                    if character.isGoldEarner {
                        Text("골드 획득 캐릭터")
                            .font(.caption)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                        // 다크모드에서 더 잘 보이도록 배경색 조정
                            .background(Color.yellow.opacity(colorScheme == .dark ? 0.2 : 0.2))
                        // 다크모드에서 색상 조정
                            .foregroundColor(colorScheme == .dark ? .orange.opacity(0.9) : .orange)
                            .cornerRadius(4)
                    }
                }
                
                Spacer()
                
                // 다음 페이지로 이동
                Button(action: {
                    goToNextPage?()
                }) {
                    Image(systemName: "chevron.right")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                    // 다크모드에서 더 잘 보이도록 색상 조정
                        .foregroundColor(goToNextPage != nil ?
                                         (colorScheme == .dark ? .blue.opacity(0.9) : .blue) :
                                            (colorScheme == .dark ? .gray.opacity(0.7) : .gray))
                        .frame(width: 44, height: 44)
                        .background(Color.clear)
                        .cornerRadius(8)
                }
                .disabled(goToNextPage == nil)
            }
            .padding(.horizontal)
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(12)
        // 다크모드에서 그림자 조정
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 5, x: 0, y: 2)
    }
}
