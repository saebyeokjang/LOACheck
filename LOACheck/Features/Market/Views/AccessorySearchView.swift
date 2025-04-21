//
//  AccessorySearchView.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 3/28/25.
//

import SwiftUI
import SwiftData

struct AccessorySearchView: View {
    var onRefresh: (Date) -> Void
    @AppStorage("apiKey") private var apiKey: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var showAlert = false
    
    // 장신구 검색 필터 상태
    @State private var selectedAccessoryType = 0  // 0: 목걸이, 1: 귀걸이, 2: 반지
    @State private var selectedEngraveEffects: [String] = []
    @State private var selectedEngraveValues: [String: Double] = [:] // 연마효과별 선택된 값
    @State private var selectedQuality: Int = 67
    @State private var searchResults: [AuctionItem] = []
    @State private var currentPage = 1
    @State private var totalPages = 1
    @State private var isPaginating = false // 페이지네이션 로딩 상태
    
    // 부위별 카테고리
    let accessoryCategories: [AccessoryCategory] = [.necklace, .earring, .ring]
    @Environment(\.colorScheme) private var colorScheme
    
    // 현재 선택된 부위에 따른 연마효과 옵션
    var currentEngraveEffects: [String] {
        return EngraveEffectManager.shared.getEngraveEffectsForCategory(
            accessoryCategories[selectedAccessoryType]
        )
    }
    
    var body: some View {
        VStack {
            if isLoading {
                loadingView
            } else if let error = errorMessage {
                errorView(message: error)
            } else {
                contentView
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("알림"),
                message: Text(errorMessage ?? ""),
                dismissButton: .default(Text("확인"))
            )
        }
    }
    
    // MARK: - 컴포넌트 뷰들
    
    private var loadingView: some View {
        ProgressView("장신구 검색 중...")
            .padding()
            .foregroundColor(Color.textPrimary)
    }
    
    private func errorView(message: String) -> some View {
        APIErrorView(message: message) {
            errorMessage = nil
        }
    }
    
    private var contentView: some View {
        ScrollView {
            VStack(spacing: 16) {
                partSelectionSection
                engraveEffectSection
                qualitySection
                searchButtonView
                
                if !searchResults.isEmpty {
                    searchResultsSection
                } else if !isLoading && errorMessage == nil {
                    emptyStateView
                }
            }
            .padding(.vertical)
        }
        .background(Color.backgroundPrimary)
    }
    
    // 부위 선택 섹션
    private var partSelectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("부위 선택")
                .font(.headline)
                .padding(.horizontal)
                .foregroundColor(Color.textPrimary)
            
            Picker("부위", selection: $selectedAccessoryType) {
                ForEach(0..<accessoryCategories.count, id: \.self) { index in
                    Text(accessoryCategories[index].name).tag(index)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .onChange(of: selectedAccessoryType) { _, _ in
                // 부위가 변경되면 연마효과 선택 초기화
                selectedEngraveEffects = []
                selectedEngraveValues = [:]
            }
        }
        .padding(.vertical, 8)
        .background(colorScheme == .dark ? Color.gray.opacity(0.1) : Color.gray.opacity(0.05))
        .cornerRadius(10)
        .padding(.horizontal)
    }
    
    // 연마효과 선택 섹션
    private var engraveEffectSection: some View {
        SearchFilterSection(title: "연마효과 선택", isExpanded: true) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(currentEngraveEffects, id: \.self) { effect in
                    engraveEffectButton(effect: effect)
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    // 연마효과 버튼
    private func engraveEffectButton(effect: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(action: {
                toggleEngraveEffect(effect)
            }) {
                HStack {
                    Text(effect)
                        .foregroundColor(selectedEngraveEffects.contains(effect) ? .white : Color.textPrimary)
                    
                    Spacer()
                    
                    if selectedEngraveEffects.contains(effect) {
                        Image(systemName: "checkmark")
                            .foregroundColor(.white)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(selectedEngraveEffects.contains(effect) ?
                            Color.blue : (colorScheme == .dark ? Color.gray.opacity(0.2) : Color.gray.opacity(0.1)))
                .cornerRadius(8)
            }
            
            // 선택된 연마효과의 가능한 값들 표시
            if selectedEngraveEffects.contains(effect),
               let effectValues = EngraveEffectManager.shared.getEngraveEffectValues(effect) {
                effectValuesScrollView(effect: effect, values: effectValues)
            }
        }
    }
    
    // 효과값 선택 스크롤뷰
    private func effectValuesScrollView(effect: String, values: [EngraveEffectValue]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(values, id: \.value) { effectValue in
                    Button(action: {
                        // 값 선택 또는 해제
                        if selectedEngraveValues[effect] == Double(effectValue.value) {
                            selectedEngraveValues.removeValue(forKey: effect)
                        } else {
                            // 효과 값을 그대로 저장 (isPercentage 고려하지 않고)
                            selectedEngraveValues[effect] = Double(effectValue.value)
                        }
                    }) {
                        Text(effectValue.displayValue)
                            .font(.caption)
                            .foregroundColor(selectedEngraveValues[effect] == Double(effectValue.value) ? .white : Color.textPrimary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(selectedEngraveValues[effect] == Double(effectValue.value) ?
                                        Color.blue : (colorScheme == .dark ? Color.gray.opacity(0.2) : Color.gray.opacity(0.1)))
                            .cornerRadius(4)
                    }
                }
            }
            .padding(.leading, 16)
            .padding(.bottom, 4)
        }
    }
    
    // 품질 선택 섹션
    private var qualitySection: some View {
        SearchFilterSection(title: "최소 품질", isExpanded: true) {
            VStack {
                Text("\(selectedQuality)")
                    .font(.headline)
                    .foregroundColor(.blue)
                
                Slider(value: Binding(
                    get: { Double(selectedQuality) },
                    set: { newValue in
                        let rawValue = Int(newValue)
                        if rawValue >= 65 && rawValue <= 69 {
                            selectedQuality = 67
                        } else {
                            selectedQuality = rawValue
                        }
                    }
                ), in: 0...100, step: 1)
            }
            .padding(.horizontal, 16)
        }
    }
    
    // 검색 버튼
    private var searchButtonView: some View {
        Button(action: performSearch) {
            Text("장신구 검색")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(10)
        }
        .padding(.horizontal)
        .disabled(selectedEngraveEffects.isEmpty)
    }
    
    // 검색 결과 없을 때 표시
    private var emptyStateView: some View {
        VStack {
            Text("부위와 연마효과를 선택하고 검색 버튼을 눌러주세요")
                .foregroundColor(Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 10)
    }
    
    // 검색 결과 섹션
    private var searchResultsSection: some View {
        VStack(alignment: .leading) {
            Text("검색 결과 (\(searchResults.count))")
                .font(.headline)
                .foregroundColor(Color.textPrimary)
                .padding(.horizontal)
            
            Divider()
                .background(Color.dividerColor)
            
            resultsListView
        }
        .padding(.top)
    }
    
    // 결과 리스트
    private var resultsListView: some View {
        LazyVStack(spacing: 0) {
            // 결과 목록
            ForEach(Array(searchResults.enumerated()), id: \.offset) { index, item in
                AccessoryResultRow(item: item)
                    .padding(.horizontal)
                
                Divider()
                    .background(Color.dividerColor)
            }
            
            paginationControls
        }
    }
    
    // 페이지네이션 컨트롤
    private var paginationControls: some View {
        Group {
            if isPaginating {
                // 로딩 인디케이터
                HStack {
                    Spacer()
                    ProgressView()
                        .padding()
                    Spacer()
                }
            } else if currentPage < totalPages {
                // 더보기 버튼
                Button(action: loadNextPage) {
                    HStack {
                        Spacer()
                        Text("더 보기")
                            .foregroundColor(.blue)
                            .padding()
                        Spacer()
                    }
                    .background(colorScheme == .dark ? Color.gray.opacity(0.15) : Color.gray.opacity(0.05))
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .padding(.top, 4)
                }
            }
        }
    }
    
    // MARK: - 메서드
    
    // 다음 페이지 로드
    private func loadNextPage() {
        guard !isPaginating && currentPage < totalPages else { return }
        
        isPaginating = true
        
        // 다음 페이지 번호
        let nextPage = currentPage + 1
        
        Task {
            let result = await MarketService.shared.searchAccessories(
                apiKey: apiKey,
                accessoryType: selectedAccessoryType,
                quality: selectedQuality,
                engraveEffects: selectedEngraveEffects,
                engraveValues: selectedEngraveValues,
                page: nextPage
            )
            
            await MainActor.run {
                isPaginating = false
                
                switch result {
                case .success(let response):
                    // 이전 결과에 새로운 결과 추가
                    let newItems = MarketService.shared.convertToAuctionItems(from: response.items)
                    searchResults.append(contentsOf: newItems)
                    currentPage = nextPage
                    
                case .failure(let error):
                    errorMessage = error.userFriendlyMessage
                }
            }
        }
    }
    
    // 연마효과 토글
    private func toggleEngraveEffect(_ effect: String) {
        if selectedEngraveEffects.contains(effect) {
            // 이미 선택된 효과라면 제거
            selectedEngraveEffects.removeAll { $0 == effect }
            // 선택된 값도 제거
            selectedEngraveValues.removeValue(forKey: effect)
        } else {
            // 선택되지 않은 효과라면 추가 (최대 3개까지)
            if selectedEngraveEffects.count < 3 {
                selectedEngraveEffects.append(effect)
            } else {
                errorMessage = "연마효과는 최대 3개까지 선택 가능합니다."
                showAlert = true
            }
        }
    }
    
    // 검색 필터 초기화
    private func clearFilters() {
        selectedEngraveEffects = []
        selectedEngraveValues = [:]
        selectedQuality = 0
        searchResults = []
    }
    
    // 실제 검색 수행
    private func performSearch() {
        // 검색 조건이 선택되지 않은 경우
        if selectedEngraveEffects.isEmpty {
            errorMessage = "연마효과를 하나 이상 선택해주세요"
            return
        }
        
        guard !apiKey.isEmpty else {
            errorMessage = "API 키가 설정되지 않았습니다. 설정 탭에서 API 키를 입력해주세요."
            return
        }
        
        isLoading = true
        errorMessage = nil
        currentPage = 1 // 새 검색 시 페이지 초기화
        
        // 실제 API 호출
        Task {
            let result = await MarketService.shared.searchAccessories(
                apiKey: apiKey,
                accessoryType: selectedAccessoryType,
                quality: selectedQuality,
                engraveEffects: selectedEngraveEffects,
                engraveValues: selectedEngraveValues,
                page: currentPage
            )
            
            await MainActor.run {
                isLoading = false
                let currentDate = Date()
                onRefresh(currentDate)
                
                switch result {
                case .success(let response):
                    // 디버깅용 로깅
                    MarketService.shared.logSearchResults(response)
                    
                    if response.totalCount == 0 || response.items.isEmpty {
                        searchResults = []
                        errorMessage = "검색 조건에 맞는 장신구가 없습니다.\n다른 조건으로 시도해보세요."
                    } else {
                        // API 응답을 UI에 표시할 AuctionItem으로 변환
                        searchResults = MarketService.shared.convertToAuctionItems(from: response.items)
                        
                        // 페이징 정보 업데이트
                        totalPages = (response.totalCount + response.pageSize - 1) / response.pageSize
                    }
                    
                case .failure(let error):
                    errorMessage = error.userFriendlyMessage
                }
            }
        }
    }
}
