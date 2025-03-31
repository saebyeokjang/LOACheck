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
    
    // 악세사리 검색 필터 상태
    @State private var selectedAccessoryType = 0  // 0: 목걸이, 1: 귀걸이, 2: 반지
    @State private var selectedEngraveEffects: [String] = []
    @State private var selectedEngraveValues: [String: Double] = [:] // 연마효과별 선택된 값
    @State private var selectedQuality: Int = 0
    @State private var searchResults: [AuctionItem] = []
    
    // 부위별 연마효과 정의
    let accessoryTypes = ["목걸이", "귀걸이", "반지"]
    let engraveEffects: [[String]] = [
        ["추가 피해", "적에게 주는 피해"],           // 목걸이
        ["공격력%", "무기 공격력%"],               // 귀걸이
        ["치명타 적중률", "치명타 피해"]             // 반지
    ]
    
    // 연마효과 상수 값 정의
    let engraveEffectValues: [String: [Double]] = [
        "추가 피해": [0.60, 1.60, 2.60],
        "적에게 주는 피해": [0.55, 1.20, 2.00],
        "공격력%": [0.40, 0.95, 1.55],
        "무기 공격력%": [0.80, 1.80, 3.00],
        "치명타 적중률": [0.40, 0.95, 1.55],
        "치명타 피해": [1.10, 2.40, 4.00]
    ]
    
    // 현재 선택된 부위에 따른 연마효과 옵션
    var currentEngraveEffects: [String] {
        return engraveEffects[selectedAccessoryType]
    }
    
    var body: some View {
        VStack {
            if isLoading {
                // 로딩 화면
                ProgressView("악세사리 검색 중...")
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
                                ForEach(0..<accessoryTypes.count, id: \.self) { index in
                                    Text(accessoryTypes[index]).tag(index)
                                }
                            }
                            .pickerStyle(.segmented)
                            .padding(.horizontal)
                            .onChange(of: selectedAccessoryType) { _, _ in
                                // 부위가 변경되면 연마효과 선택 초기화
                                selectedEngraveEffects = []
                            }
                        }
                        .padding(.vertical, 8)
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(10)
                        .padding(.horizontal)
                        
                        // 연마효과 선택 섹션
                        SearchFilterSection(title: "연마효과 선택 (최대 2개)", isExpanded: true) {
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
                                    if selectedEngraveEffects.contains(effect) {
                                        HStack {
                                            ForEach(engraveEffectValues[effect] ?? [], id: \.self) { value in
                                                Button(action: {
                                                    // 값 선택 또는 해제
                                                    if selectedEngraveValues[effect] == value {
                                                        selectedEngraveValues.removeValue(forKey: effect)
                                                    } else {
                                                        selectedEngraveValues[effect] = value
                                                    }
                                                }) {
                                                    Text(String(format: "%.2f%%", value))
                                                        .font(.caption)
                                                        .foregroundColor(selectedEngraveValues[effect] == value ? .white : .primary)
                                                        .padding(.horizontal, 8)
                                                        .padding(.vertical, 4)
                                                        .background(selectedEngraveValues[effect] == value ?
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
                            Text("악세사리 검색")
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
                                ForEach(searchResults) { item in
                                    AccessoryResultRow(item: item)
                                        .padding(.horizontal)
                                    
                                    Divider()
                                }
                            }
                            .padding(.top)
                        } else if !isLoading && errorMessage == nil {
                            // 검색 결과 없음 (초기 상태 또는 검색 결과 없음)
                            VStack {
                                Image(systemName: "diamond.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.gray)
                                    .padding()
                                
                                Text("부위와 연마효과를 선택하고 검색 버튼을 눌러주세요")
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.top, 40)
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
    
    // 연마효과 토글 (최대 2개까지만 선택 가능)
    private func toggleEngraveEffect(_ effect: String) {
        if selectedEngraveEffects.contains(effect) {
            // 이미 선택된 효과라면 제거
            selectedEngraveEffects.removeAll { $0 == effect }
            // 선택된 값도 제거
            selectedEngraveValues.removeValue(forKey: effect)
        } else {
            // 선택되지 않은 효과라면 추가 (최대 2개까지)
            if selectedEngraveEffects.count < 2 {
                selectedEngraveEffects.append(effect)
                // 기본값으로 첫 번째 값 선택
                if let firstValue = engraveEffectValues[effect]?.first {
                    selectedEngraveValues[effect] = firstValue
                }
            } else {
                // 이미 2개가 선택된 경우, 사용자에게 알림
                errorMessage = "연마효과는 최대 2개까지 선택 가능합니다."
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
        
        // 선택된 모든 연마효과에 값이 선택되었는지 확인
        for effect in selectedEngraveEffects {
            if selectedEngraveValues[effect] == nil {
                errorMessage = "\(effect)의 연마효과 값을 선택해주세요"
                showAlert = true
                return
            }
        }
        
        guard !apiKey.isEmpty else {
            errorMessage = "API 키가 설정되지 않았습니다. 설정 탭에서 API 키를 입력해주세요."
            showAlert = true
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // API 호출 시뮬레이션 (2초 후 결과 반환)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isLoading = false
            let currentDate = Date()
            onRefresh(currentDate)
            
            // 임시 데이터 생성 (실제 API 응답을 파싱해야 함)
            if Int.random(in: 0...10) > 1 { // 90% 성공률
                self.searchResults = self.generateSampleResults()
            } else {
                self.errorMessage = "악세사리 검색 중 오류가 발생했습니다. 다시 시도해주세요."
                self.showAlert = true
            }
        }
    }
    
    // 샘플 데이터 생성 (실제 구현 시 제거)
    private func generateSampleResults() -> [AuctionItem] {
        var results: [AuctionItem] = []
        
        // 부위 이름
        let accessoryTypeName = accessoryTypes[selectedAccessoryType]
        
        // 악세사리 아이콘 URL
        let iconURLs = [
            "https://cdn-lostark.game.onstove.com/efui_iconatlas/acc_necklace.png",  // 목걸이
            "https://cdn-lostark.game.onstove.com/efui_iconatlas/acc_earring.png",   // 귀걸이
            "https://cdn-lostark.game.onstove.com/efui_iconatlas/acc_ring.png"       // 반지
        ]
        
        // 15개의 샘플 결과 생성
        for i in 1...15 {
            let quality = max(selectedQuality, Int.random(in: selectedQuality...100))
            
            var options: [ItemOption] = []
            
            // 선택된 모든 연마효과를 옵션에 추가 (사용자가 선택한 특정 값 사용)
            for effect in selectedEngraveEffects {
                // 사용자가 선택한 값 가져오기 (없으면 첫번째 값 사용)
                let value = selectedEngraveValues[effect] ??
                          (engraveEffectValues[effect]?.first ?? 1.0)
                
                options.append(
                    ItemOption(
                        type: "ENGRAVE_EFFECT",
                        optionName: effect,
                        value: value,
                        isPenalty: false
                    )
                )
            }
            
            let item = AuctionItem(
                name: "유물 \(quality)% \(accessoryTypeName)",
                grade: "유물",
                tier: 3,
                icon: iconURLs[selectedAccessoryType],
                auctionInfo: AuctionInfo(
                    startPrice: Int.random(in: 1000...100000) * 10,
                    buyPrice: nil,
                    bidPrice: Int.random(in: 1000...100000) * 10,
                    endDate: Date().addingTimeInterval(86400),
                    bidCount: Int.random(in: 0...5),
                    bidStartPrice: Int.random(in: 1000...100000) * 10
                ),
                options: options
            )
            
            results.append(item)
        }
        
        // 가격 오름차순 정렬
        return results.sorted { $0.auctionInfo.bidStartPrice < $1.auctionInfo.bidStartPrice }
    }
}
