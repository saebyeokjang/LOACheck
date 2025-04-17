//
//  CharacterPagingView.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 3/20/25.
//

import SwiftUI
import SwiftData

struct CharacterPagingView: View {
    @State private var characters: [CharacterModel] = []
    @State private var isCharacterLoading = true
    var goToSettingsAction: (() -> Void)?
    @State private var currentPage = 0
    @State private var isPageChanging = false // 페이지 전환 중 상태
    @State private var dragOffset: CGFloat = 0 // 드래그 상태 추적
    @State private var screenWidth: CGFloat = UIScreen.main.bounds.width // 화면 너비
    @State private var showCharacterSelector = false // 캐릭터 선택기 표시 여부
    @State private var animationDirection: Int = 0 // 애니메이션 방향 (1: 다음 페이지, -1: 이전 페이지, 0: 없음)
    @State private var isAnimating = false // 애니메이션 진행 중 상태
    @State private var showGoldSummary = false // 골드 요약 시트 표시 여부
    
    @Environment(\.modelContext) private var modelContext
    
    init(goToSettingsAction: (() -> Void)? = nil) {
        self.goToSettingsAction = goToSettingsAction
    }
    
    var body: some View {
        VStack {
            // 데이터 로딩 중 화면 추가
            if isCharacterLoading {
                ProgressView("데이터 불러오는 중...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if characters.isEmpty {
                EmptyCharactersView(goToSettingsAction: goToSettingsAction)
            } else {
                // 상단 네비게이션 바
                HStack {
                    // 바로가기 버튼
                    Button(action: {
                        // 동기화
                        if AuthManager.shared.isLoggedIn && DataSyncManager.shared.hasPendingChanges && NetworkMonitorService.shared.isConnected {
                            Task {
                                let result = await DataSyncManager.shared.uploadToServer()
                                Logger.debug("캐릭터 바로가기로 인한 동기화 결과: \(result ? "성공" : "실패")")
                            }
                        }
                        showCharacterSelector = true
                    }) {
                        HStack(spacing: 4) {
                            Text("캐릭터 바로가기")
                                .font(.caption)
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    Spacer()
                    
                    // 골드 요약 버튼
                    Button(action: {
                        showGoldSummary = true
                    }) {
                        HStack(spacing: 4) {
                            Text("주간 획득 골드")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.orange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.yellow.opacity(0.2))
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
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
                                    isCurrentlyActive: index == currentPage && !isPageChanging,
                                    goToPreviousPage: index > 0 ? { navigateToPage(index - 1) } : nil,
                                    goToNextPage: index < characters.count - 1 ? { navigateToPage(index + 1) } : nil
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
                                withAnimation(.interpolatingSpring(stiffness: 300, damping: 30)) {
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
        .onAppear {
            loadCharacters()
        }
        .onChange(of: currentPage) { oldValue, newValue in
            Logger.debug("Page changed from \(oldValue) to \(newValue)")
        }
        // 주기적으로 캐릭터 목록 새로고침 - 데이터 변경 감지용
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshCharacterList"))) { _ in
            loadCharacters()
        }
        .sheet(isPresented: $showCharacterSelector) {
            CharacterSelectorView(
                characters: characters,
                currentPage: $currentPage,
                dismiss: { showCharacterSelector = false },
                navigateToPage: navigateToPage
            )
        }
        .sheet(isPresented: $showGoldSummary) {
            NavigationStack {
                GoldSummaryView()
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("닫기") {
                                showGoldSummary = false
                            }
                        }
                    }
            }
        }
    }
    
    // SwiftData 수동 로드 기능 추가
    func loadCharacters() {
            // 로딩 상태 활성화
            isCharacterLoading = true
            
            print("캐릭터 데이터 로딩 시작")
            Task {
                await MainActor.run {
                    do {
                        var descriptor = FetchDescriptor<CharacterModel>()
                        descriptor.predicate = #Predicate<CharacterModel> { !$0.isHidden }
                        descriptor.sortBy = [SortDescriptor(\CharacterModel.level, order: .reverse)]
                        
                        // 데이터 가져오기
                        let newCharacters = try modelContext.fetch(descriptor)
                        print("캐릭터 \(newCharacters.count)개 로드 완료")
                        
                        // 기존 캐릭터 수와 현재 페이지 확인
                        let oldCount = characters.count
                        
                        // 캐릭터 목록 업데이트
                        characters = newCharacters
                        
                        // 현재 페이지가 유효한지 확인하고 필요시 조정
                        if characters.isEmpty {
                            currentPage = 0
                        } else if currentPage >= characters.count {
                            // 현재 페이지가 유효하지 않은 경우 마지막 페이지로 조정
                            currentPage = max(0, characters.count - 1)
                            Logger.debug("캐릭터 목록 변경으로 현재 페이지 조정: \(currentPage)")
                        }
                        
                        // 짧은 지연 후 로딩 완료 처리
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            isCharacterLoading = false
                        }
                    } catch {
                        print("캐릭터 로드 오류: \(error.localizedDescription)")
                        // 에러 발생해도 로딩 완료 처리
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            isCharacterLoading = false
                        }
                    }
                }
            }
        }
    
    // 특정 페이지가 보여져야 하는지 결정 (성능 최적화)
    private func shouldShowPage(_ index: Int) -> Bool {
        return abs(index - currentPage) <= 1 // 현재 페이지와 인접 페이지만 로드
    }
    
    // 페이지 오프셋 계산 (드래그 효과 적용)
    private func calculateOffset(for index: Int, in geometry: GeometryProxy) -> CGFloat {
        let pageOffset = CGFloat(index - currentPage) * geometry.size.width
        
        // 드래그 중이거나 애니메이션 중일 때 오프셋 적용
        if isAnimating && animationDirection != 0 {
            // 버튼 클릭 애니메이션 중일 때
            return pageOffset + dragOffset
        } else {
            // 일반 드래그 중일 때
            return pageOffset + dragOffset
        }
    }
    
    // 페이지 이동 애니메이션 함수
    private func navigateToPage(_ newPage: Int) {
        guard newPage >= 0 && newPage < characters.count && !isAnimating else { return }
        
        // 애니메이션 방향 설정 (이전 페이지: -1, 다음 페이지: 1)
        animationDirection = newPage > currentPage ? 1 : -1
        isAnimating = true
        isPageChanging = true
        
        // 시작 위치 설정 (화면 너비의 25%)
        dragOffset = CGFloat(-animationDirection) * screenWidth * 0.25
        
        // 햅틱 피드백
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        // 애니메이션 시작
        withAnimation(.interpolatingSpring(stiffness: 500, damping: 100)) {
            dragOffset = 0
            currentPage = newPage
        }
        
        // 애니메이션 완료 후 상태 초기화
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            animationDirection = 0
            isAnimating = false
            isPageChanging = false
            
            // 데이터 동기화 추가
            if AuthManager.shared.isLoggedIn && DataSyncManager.shared.hasPendingChanges && NetworkMonitorService.shared.isConnected {
                Task {
                    let result = await DataSyncManager.shared.uploadToServer()
                    Logger.debug("페이지 이동으로 인한 동기화 결과: \(result ? "성공" : "실패")")
                }
            }
        }
    }
}

// 캐릭터 선택 시트 뷰
struct CharacterSelectorView: View {
    let characters: [CharacterModel]
    @Binding var currentPage: Int
    var dismiss: () -> Void
    var navigateToPage: (Int) -> Void
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("캐릭터 바로가기")) {
                    ForEach(Array(characters.enumerated()), id: \.element.id) { index, character in
                        Button(action: {
                            navigateToPage(index)
                            dismiss()
                        }) {
                            HStack {
                                // 캐릭터 정보
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(character.name)
                                        .font(.headline)
                                    
                                    Text("\(character.server) • \(character.characterClass)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    Text("레벨: \(String(format: "%.2f", character.level))")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                // 현재 선택된 캐릭터 표시
                                if index == currentPage {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                Section(footer: Text("현재 '보기'가 체크된 캐릭터만 표시됩니다.")) {
                    EmptyView()
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("캐릭터 선택")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") {
                        dismiss()
                    }
                }
            }
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
