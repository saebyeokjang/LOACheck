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
    @State private var isPageChanging = false
    @State private var dragOffset: CGFloat = 0
    @State private var screenWidth: CGFloat = UIScreen.main.bounds.width
    @State private var showCharacterSelector = false
    @State private var animationDirection: Int = 0
    @State private var isAnimating = false
    @State private var showGoldSummary = false
    
    // Task 관리를 위한 상태 변수 추가
    @State private var loadingTask: Task<Void, Never>? = nil
    @State private var refreshTask: Task<Void, Never>? = nil
    
    @Environment(\.modelContext) private var modelContext
    
    init(goToSettingsAction: (() -> Void)? = nil) {
        self.goToSettingsAction = goToSettingsAction
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // SafeArea 위쪽 여백을 추가하는 빈 뷰
            Color.clear
                .frame(height: 0)
                .padding(.top, 1) // 최소한의 패딩
            
            // 캐릭터 로딩 중 화면 추가
            if isCharacterLoading {
                ProgressView("캐릭터 불러오는 중...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if characters.isEmpty {
                EmptyCharactersView(goToSettingsAction: goToSettingsAction)
            } else {
                // 상단 네비게이션 바 - 상태바 아래에 배치
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
                    
                    // 캐릭터 갱신 버튼 - 가운데에 추가
                    Button(action: {
                        // 이미 로딩 중이면 무시
                        guard !isCharacterLoading else { return }
                        refreshCurrentCharacter()
                    }) {
                        HStack(spacing: 4) {
                            Text("캐릭터 갱신")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(Color.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .disabled(isCharacterLoading || characters.isEmpty)
                    .opacity(isCharacterLoading ? 0.5 : 1.0)
                    
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
                .padding(.horizontal, 16)
                .padding(.top, 16) // 상단 여백 증가
                .padding(.bottom, 8)
                .frame(height: 52) // 높이를 증가
                .zIndex(1)
                
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
                .zIndex(0)
            }
        }
        .background(Color.backgroundPrimary)
        .ignoresSafeArea(.all, edges: []) // 안전 영역 전체 무시하지 않음
        .safeAreaInset(edge: .top) {
            // 상단 Safe Area에 투명한 공간 추가
            Color.clear.frame(height: 0)
        }
        .onAppear {
            loadCharacters()
        }
        .onChange(of: currentPage) { oldValue, newValue in
            Logger.debug("Page changed from \(oldValue) to \(newValue)")
        }
        // 주기적으로 캐릭터 목록 새로고침 - 데이터 변경 감지용
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshCharacterList"))) { _ in
            // 현재 로딩 중이면 중복 로드 방지
            if !isCharacterLoading {
                loadCharacters()
            }
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
    
    // 현재 표시된 캐릭터 갱신 함수
    private func refreshCurrentCharacter() {
        guard !characters.isEmpty && currentPage < characters.count else { return }
        
        // 이미 로딩 중인 경우 무시
        guard !isCharacterLoading else { return }
        
        // 이전 작업 취소
        refreshTask?.cancel()
        isCharacterLoading = true
        
        refreshTask = Task {
            if let apiKey = UserDefaults.standard.string(forKey: "apiKey"), !apiKey.isEmpty {
                let currentCharacter = characters[currentPage]
                let result = await LostArkAPIService.shared.updateSingleCharacterViaArmory(
                    name: currentCharacter.name,
                    apiKey: apiKey,
                    modelContext: modelContext
                )
                
                if Task.isCancelled { return }
                
                await MainActor.run {
                    // 동기화 표시
                    DataSyncManager.shared.markLocalChanges()
                    
                    // 현재 캐릭터 정보만 직접 업데이트하고 전체 목록은 다시 로드하지 않음
                    if case .success = result {
                        // 캐릭터 정보가 업데이트되었으므로 현재 배열에서 해당 캐릭터 찾아서 업데이트
                        if let index = characters.firstIndex(where: { $0.id == currentCharacter.id }) {
                            characters[index] = currentCharacter
                        }
                    }
                    
                    // 자동 동기화 수행
                    if AuthManager.shared.isLoggedIn && NetworkMonitorService.shared.isConnected {
                        Task {
                            await DataSyncManager.shared.uploadToServer()
                        }
                    }
                    
                    // 로딩 상태 해제
                    isCharacterLoading = false
                }
            } else {
                if !Task.isCancelled {
                    await MainActor.run {
                        isCharacterLoading = false
                    }
                }
            }
        }
    }
    
    func loadCharacters() {
        // 이전 작업이 있으면 취소하여 동시 실행 방지
        loadingTask?.cancel()
        
        // 로딩 상태 활성화
        isCharacterLoading = true
        
        // 새 작업 시작
        loadingTask = Task {
            do {
                // 메인 스레드에서 안전하게 데이터 가져오기
                let newCharacters = try await MainActor.run {
                    var descriptor = FetchDescriptor<CharacterModel>()
                    descriptor.predicate = #Predicate<CharacterModel> { !$0.isHidden }
                    descriptor.sortBy = [SortDescriptor(\CharacterModel.level, order: .reverse)]
                    
                    return try modelContext.fetch(descriptor)
                }
                
                // 작업이 취소되었는지 확인
                if Task.isCancelled { return }
                
                await MainActor.run {
                    // 캐릭터 목록 업데이트
                    characters = newCharacters
                    
                    // 현재 페이지가 유효한지 확인하고 필요시 조정
                    if characters.isEmpty {
                        currentPage = 0
                    } else if currentPage >= characters.count {
                        currentPage = max(0, characters.count - 1)
                    }
                }
                
                // 짧은 지연 후 로딩 완료 처리
                try await Task.sleep(nanoseconds: 300_000_000) // 0.3초 대기
                
                if !Task.isCancelled {
                    await MainActor.run {
                        isCharacterLoading = false
                    }
                }
            } catch {
                if !Task.isCancelled {
                    await MainActor.run {
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
