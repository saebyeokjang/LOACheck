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
    @State private var selectedQuality: Int = 0
    @State private var searchResults: [AuctionItem] = []
    @State private var currentPage = 1
    @State private var totalPages = 1
    
    // 부위별 카테고리
    let accessoryCategories: [AccessoryCategory] = [.necklace, .earring, .ring]
    
    // 현재 선택된 부위에 따른 연마효과 옵션
    var currentEngraveEffects: [String] {
        return EngraveEffectManager.shared.getEngraveEffectsForCategory(
            accessoryCategories[selectedAccessoryType]
        )
    }
    
    var body: some View {
        VStack {
            if isLoading {
                // 로딩 화면
                ProgressView("장신구 검색 중...")
                    .padding()
            } else if let error = errorMessage {
                // 에러 화면
                ErrorView(message: error) {
                    // 재시도 버튼 액션
                    errorMessage = nil
                }
            } else {
                // 검색 필터 섹션
                ScrollView {
                    VStack(spacing: 16) {
                        // 부위 선택 세그먼트
                        VStack(alignment: .leading, spacing: 8) {
                            Text("부위 선택")
                                .font(.headline)
                                .padding(.horizontal)
                            
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
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(10)
                        .padding(.horizontal)
                        
                        // 연마효과 선택 섹션
                        SearchFilterSection(title: "연마효과 선택", isExpanded: true) {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(currentEngraveEffects, id: \.self) { effect in
                                    Button(action: {
                                        toggleEngraveEffect(effect)
                                    }) {
                                        HStack {
                                            Text(effect)
                                                .foregroundColor(selectedEngraveEffects.contains(effect) ? .white : .primary)
                                            
                                            Spacer()
                                            
                                            if selectedEngraveEffects.contains(effect) {
                                                Image(systemName: "checkmark")
                                                    .foregroundColor(.white)
                                            }
                                        }
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                        .background(selectedEngraveEffects.contains(effect) ? Color.blue : Color.gray.opacity(0.1))
                                        .cornerRadius(8)
                                    }
                                    
                                    // 선택된 연마효과의 가능한 값들 표시 (선택 가능하도록 변경)
                                    if selectedEngraveEffects.contains(effect),
                                       let effectValues = EngraveEffectManager.shared.getEngraveEffectValues(effect) {
                                        // 하드코딩 된 값 표시
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack {
                                                ForEach(effectValues, id: \.value) { effectValue in
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
                                                            .foregroundColor(selectedEngraveValues[effect] == Double(effectValue.value) ? .white : .primary)
                                                            .padding(.horizontal, 8)
                                                            .padding(.vertical, 4)
                                                            .background(selectedEngraveValues[effect] == Double(effectValue.value) ?
                                                                        Color.blue : Color.gray.opacity(0.1))
                                                            .cornerRadius(4)
                                                    }
                                                }
                                            }
                                            .padding(.leading, 16)
                                            .padding(.bottom, 4)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        
                        // 품질 선택 섹션
                        SearchFilterSection(title: "최소 품질", isExpanded: true) {
                            VStack {
                                Text("\(selectedQuality)")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                                
                                Slider(value: Binding(
                                    get: { Double(selectedQuality) },
                                    set: { selectedQuality = Int($0) }
                                ), in: 0...100, step: 10)
                            }
                            .padding(.horizontal, 16)
                        }
                        
                        // 검색 버튼
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
                        
                        if !searchResults.isEmpty {
                            // 검색 결과 섹션
                            VStack(alignment: .leading) {
                                Text("검색 결과 (\(searchResults.count))")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                Divider()
                                
                                // 결과 목록
                                ForEach(Array(searchResults.enumerated()), id: \.offset) { index, item in
                                    AccessoryResultRow(item: item)
                                        .padding(.horizontal)
                                    
                                    Divider()
                                }
                            }
                            .padding(.top)
                        } else if !isLoading && errorMessage == nil {
                            // 검색 결과 없음 (초기 상태 또는 검색 결과 없음)
                            VStack {
                                Text("부위와 연마효과를 선택하고 검색 버튼을 눌러주세요")
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.top, 10)
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: clearFilters) {
                    Label("필터 초기화", systemImage: "xmark.circle")
                }
                .disabled(selectedEngraveEffects.isEmpty && selectedQuality == 0)
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
    
    // 연마효과 토글 (최대 3개까지만 선택 가능)
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
    
    // 실제 검색 수행 (API 호출)
    private func performSearch() {
        // 검색 조건이 선택되지 않은 경우
        if selectedEngraveEffects.isEmpty {
            errorMessage = "연마효과를 하나 이상 선택해주세요"
            showAlert = true
            return
        }
        
        guard !apiKey.isEmpty else {
            errorMessage = "API 키가 설정되지 않았습니다. 설정 탭에서 API 키를 입력해주세요."
            showAlert = true
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // 실제 API 호출
        Task {
            let result = await MarketService.shared.searchAccessories(
                apiKey: apiKey,
                accessoryType: selectedAccessoryType,
                quality: selectedQuality,
                engraveEffects: selectedEngraveEffects,
                engraveValues: selectedEngraveValues
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
                        showAlert = true
                    } else {
                        // API 응답을 UI에 표시할 AuctionItem으로 변환
                        searchResults = MarketService.shared.convertToAuctionItems(from: response.items)
                        
                        // 페이징 정보 업데이트
                        currentPage = response.pageNo
                        totalPages = (response.totalCount + response.pageSize - 1) / response.pageSize
                    }
                    
                case .failure(let error):
                    errorMessage = "검색 중 오류가 발생했습니다: \(error.localizedDescription)"
                    showAlert = true
                }
            }
        }
    }
}
