//
//  CharacterPagingView.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 3/20/25.
//

import SwiftUI
import SwiftData

struct CharacterPagingView: View {
    @Query var characters: [CharacterModel]
    var goToSettingsAction: (() -> Void)?
    @State private var currentPage = 0
    
    init(goToSettingsAction: (() -> Void)? = nil) {
        var descriptor = FetchDescriptor<CharacterModel>(predicate: #Predicate<CharacterModel> { !$0.isHidden })
        descriptor.sortBy = [SortDescriptor(\CharacterModel.level, order: .reverse)]
        _characters = Query(descriptor)
        self.goToSettingsAction = goToSettingsAction
    }
    
    var body: some View {
        VStack {
            if characters.isEmpty {
                EmptyCharactersView(goToSettingsAction: goToSettingsAction)
            } else {
                // 페이지 번호 표시 (선택적)
                Text("\(currentPage + 1) / \(characters.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
                
                TabView(selection: $currentPage) {
                    ForEach(Array(characters.enumerated()), id: \.element.id) { index, character in
                        CharacterDetailView(character: character)
                            .padding(.horizontal)
                            .tag(index)
                            // 페이지가 나타날 때 프리페칭 로직 추가 가능
                            .onAppear {
                                prefetchAdjacentPages(currentIndex: index)
                            }
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
                // 페이지 전환 애니메이션 커스터마이징
                .animation(.easeInOut, value: currentPage)
                .transition(.opacity)
                // 페이지 인디케이터 커스텀
                .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .interactive))
                // 페이지 변경 감지
                .onChange(of: currentPage) { oldValue, newValue in
                    // 햅틱 피드백 제공 (선택적)
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    
                    // 페이지 변경 시 필요한 작업 수행
                    Logger.debug("Page changed from \(oldValue) to \(newValue)")
                }
            }
        }
    }
    
    // 인접 페이지 프리페칭 (성능 최적화)
    private func prefetchAdjacentPages(currentIndex: Int) {
        // 다음 페이지와 이전 페이지를 미리 준비하는 로직
        // 필요한 경우 리소스를 미리 로드
        let prevIndex = max(0, currentIndex - 1)
        let nextIndex = min(characters.count - 1, currentIndex + 1)
        
        // 필요한 경우 여기서 데이터 프리로딩
        if prevIndex != currentIndex {
            // 이전 페이지 관련 데이터 준비
        }
        
        if nextIndex != currentIndex {
            // 다음 페이지 관련 데이터 준비
        }
    }
}

struct EmptyCharactersView: View {
    var goToSettingsAction: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("표시할 캐릭터가 없습니다")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("API 키를 등록하여 캐릭터를 불러오거나\n숨김 처리된 캐릭터를 확인해보세요.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
            
            Button(action: {
                goToSettingsAction?() // 클로저 호출
            }) {
                Text("설정으로 이동")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .padding()
    }
}

struct CharacterDetailView: View {
    var character: CharacterModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 캐릭터 정보 헤더
                CharacterHeaderView(character: character)
                
                // 일일 숙제 섹션
                if let dailyTasks = character.dailyTasks, !dailyTasks.isEmpty {
                    DailyTasksView(tasks: dailyTasks)
                }
                
                // 주간 레이드 섹션
                WeeklyRaidsView(character: character)
                
                Spacer()
            }
            .padding(.bottom, 20)
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
