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
    @State private var isPageChanging = false // 페이지 전환 중 상태
    @State private var dragOffset: CGFloat = 0 // 드래그 상태 추적
    @State private var screenWidth: CGFloat = UIScreen.main.bounds.width // 화면 너비
    
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
                // 페이지 번호만 표시 (화살표 제거)
                Text("\(currentPage + 1) / \(characters.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
                
                // 각 페이지의 너비를 측정하기 위한 GeometryReader
                GeometryReader { geometry in
                    // 드래그 중에 화면 이동 효과를 위한 ZStack
                    ZStack {
                        // 페이지 뷰 추적
                        ForEach(0..<characters.count, id: \.self) { index in
                            if shouldShowPage(index) { // 불필요한 페이지는 로드하지 않음
                                CharacterDetailView(
                                    character: characters[index],
                                    isCurrentlyActive: index == currentPage && !isPageChanging
                                )
                                .padding(.horizontal)
                                .frame(width: geometry.size.width)
                                .offset(x: calculateOffset(for: index, in: geometry))
                            }
                        }
                    }
                    .onAppear {
                        screenWidth = geometry.size.width
                    }
                    .contentShape(Rectangle()) // 전체 영역을 제스처 감지 영역으로 설정
                    .gesture(
                        // 스와이프 제스처
                        DragGesture()
                            .onChanged { value in
                                // 드래그 시작 시 페이지 전환 중 상태로 설정
                                isPageChanging = true
                                // 드래그 거리를 저장 (화면 이동에 사용)
                                dragOffset = value.translation.width
                            }
                            .onEnded { value in
                                // 스와이프 방향과 거리에 따라 페이지 전환 결정
                                let threshold: CGFloat = geometry.size.width * 0.2 // 화면 너비의 20%
                                
                                // 페이지 전환 애니메이션
                                withAnimation(.easeOut(duration: 0.3)) {
                                    if value.translation.width > threshold && currentPage > 0 {
                                        // 오른쪽으로 스와이프 - 이전 페이지
                                        currentPage -= 1
                                        // 햅틱 피드백
                                        let generator = UIImpactFeedbackGenerator(style: .light)
                                        generator.impactOccurred()
                                    } else if value.translation.width < -threshold && currentPage < characters.count - 1 {
                                        // 왼쪽으로 스와이프 - 다음 페이지
                                        currentPage += 1
                                        // 햅틱 피드백
                                        let generator = UIImpactFeedbackGenerator(style: .light)
                                        generator.impactOccurred()
                                    }
                                    
                                    // 드래그 오프셋 초기화
                                    dragOffset = 0
                                }
                                
                                // 드래그 종료 후 상태 업데이트
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    isPageChanging = false
                                }
                            }
                    )
                }
            }
        }
        .onChange(of: currentPage) { oldValue, newValue in
            Logger.debug("Page changed from \(oldValue) to \(newValue)")
        }
    }
    
    // 특정 페이지가 보여져야 하는지 결정 (성능 최적화)
    private func shouldShowPage(_ index: Int) -> Bool {
        return abs(index - currentPage) <= 1 // 현재 페이지와 인접 페이지만 로드
    }
    
    // 페이지 오프셋 계산 (드래그 효과 적용)
    private func calculateOffset(for index: Int, in geometry: GeometryProxy) -> CGFloat {
        let pageOffset = CGFloat(index - currentPage) * geometry.size.width
        
        // 드래그 중일 때는 드래그 거리를 반영
        return pageOffset + dragOffset
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
