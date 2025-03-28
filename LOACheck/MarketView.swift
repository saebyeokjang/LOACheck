//
//  MarketView.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 3/28/25.
//

import SwiftUI
import SwiftData

struct MarketView: View {
    @AppStorage("lastMarketTab") private var selectedTab = 0
    @State private var lastRefreshedTime: Date? = nil
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 마지막 갱신 시간
                if let lastRefreshed = lastRefreshedTime {
                    HStack {
                        Spacer()
                        Text("마지막 갱신: \(lastRefreshed.formatted(date: .omitted, time: .shortened))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                
                // 상단 세그먼트 컨트롤
                Picker("시세 종류", selection: $selectedTab) {
                    Text("악세사리").tag(0)
                    Text("보석").tag(1)
                    Text("각인서").tag(2)
                }
                .pickerStyle(.segmented)
                .padding()
                
                // 선택된 탭에 따라 다른 뷰 표시
                TabView(selection: $selectedTab) {
                    AccessorySearchView(onRefresh: { date in
                        lastRefreshedTime = date
                    })
                    .tag(0)
                    
                    GemPriceView(onRefresh: { date in
                        lastRefreshedTime = date
                    })
                    .tag(1)
                    
                    EngravingBookView(onRefresh: { date in
                        lastRefreshedTime = date
                    })
                    .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never)) // 페이지 인디케이터 숨김
                .animation(.easeInOut, value: selectedTab)
            }
            .navigationTitle("시세 검색")
        }
    }
}

// 기존 AuctionView를 리팩토링한 각인서 시세 뷰
struct EngravingBookView: View {
    var onRefresh: (Date) -> Void
    @AppStorage("apiKey") private var apiKey: String = ""
    @State private var auctionItems: [AuctionItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var showAlert = false
    @State private var searchText = ""
    @State private var currentPage = 1
    @State private var totalPages = 1
    @State private var isPaginating = false
    @State private var pageSize = 10
    
    // 필터링된 아이템
    var filteredItems: [AuctionItem] {
        let filteredBySearch = searchText.isEmpty ? auctionItems : auctionItems.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.engraveName.localizedCaseInsensitiveContains(searchText)
        }
        
        // 가격 내림차순으로 고정
        return filteredBySearch.sorted { $0.auctionInfo.bidStartPrice > $1.auctionInfo.bidStartPrice }
    }
    
    var body: some View {
        VStack {
            if isLoading && !isPaginating {
                // 로딩 화면
                ProgressView("경매장 데이터 불러오는 중...")
                    .padding()
            } else if let error = errorMessage {
                // 에러 화면
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    
                    Text("데이터를 불러올 수 없습니다")
                        .font(.headline)
                    
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button(action: loadAuctionData) {
                        Text("다시 시도")
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .padding(.top, 8)
                }
                .padding()
            } else if auctionItems.isEmpty {
                // 빈 화면
                VStack(spacing: 16) {
                    Image(systemName: "cart")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    
                    Text("시장 데이터가 없습니다")
                        .font(.headline)
                    
                    Text("설정에서 API 키를 확인하고 새로고침 해주세요")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button(action: loadAuctionData) {
                        Text("데이터 불러오기")
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .padding(.top, 8)
                }
                .padding()
            } else {
                // 검색창
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("각인서 이름 검색", text: $searchText)
                        .autocorrectionDisabled()
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                
                // 데이터 표시
                List {
                    ForEach(filteredItems) { item in
                        AuctionItemRow(item: item)
                    }
                    
                    // 페이지네이션 로딩 인디케이터
                    if isPaginating && currentPage < totalPages {
                        HStack {
                            Spacer()
                            ProgressView()
                                .padding()
                            Spacer()
                        }
                        .onAppear {
                            loadNextPage()
                        }
                    } else if currentPage < totalPages {
                        // 더보기 버튼
                        HStack {
                            Spacer()
                            Button(action: loadNextPage) {
                                Text("더 보기")
                                    .foregroundColor(.blue)
                            }
                            Spacer()
                        }
                        .padding()
                        .background(Color.white)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 20, trailing: 0))
                    }
                }
                .listStyle(PlainListStyle())
                .refreshable {
                    await refreshAuctionData()
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: loadAuctionData) {
                    Label("새로고침", systemImage: "arrow.clockwise")
                }
                .disabled(isLoading)
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("알림"),
                message: Text(errorMessage ?? ""),
                dismissButton: .default(Text("확인"))
            )
        }
        .onAppear {
            loadAuctionData()
        }
    }
    
    // 경매장 데이터 로드
    private func loadAuctionData() {
        guard !apiKey.isEmpty else {
            errorMessage = "API 키가 설정되지 않았습니다. 설정 탭에서 API 키를 입력해주세요."
            showAlert = true
            return
        }
        
        isLoading = true
        errorMessage = nil
        currentPage = 1 // 페이지 초기화
        
        Task {
            let result = await AuctionService.shared.fetchRelicEngraveBooks(apiKey: apiKey, page: currentPage)
            
            await MainActor.run {
                isLoading = false
                let currentDate = Date()
                onRefresh(currentDate)
                
                switch result {
                case .success(let auction):
                    auctionItems = auction.items.map { marketItem in
                        AuctionItem(
                            name: marketItem.name,
                            grade: marketItem.grade,
                            tier: 3,
                            icon: marketItem.icon,
                            auctionInfo: AuctionInfo(
                                startPrice: marketItem.currentMinPrice,
                                buyPrice: nil,
                                bidPrice: marketItem.currentMinPrice,
                                endDate: Date(),
                                bidCount: 0,
                                bidStartPrice: marketItem.currentMinPrice
                            ),
                            options: []
                        )
                    }
                    
                    // 페이지네이션 정보 업데이트
                    pageSize = auction.pageSize
                    totalPages = (auction.totalCount + pageSize - 1) / pageSize
                    
                    if auctionItems.isEmpty {
                        errorMessage = "유물 등급 각인서를 찾을 수 없습니다."
                        showAlert = true
                    }
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    showAlert = true
                }
            }
        }
    }
    
    // 다음 페이지 로드 (페이지네이션)
    private func loadNextPage() {
        guard !isPaginating && currentPage < totalPages else { return }
        
        isPaginating = true
        
        Task {
            let nextPage = currentPage + 1
            let result = await AuctionService.shared.fetchRelicEngraveBooks(apiKey: apiKey, page: nextPage)
            
            await MainActor.run {
                isPaginating = false
                
                switch result {
                case .success(let auction):
                    let newItems = auction.items.map { marketItem in
                        AuctionItem(
                            name: marketItem.name,
                            grade: marketItem.grade,
                            tier: 3,
                            icon: marketItem.icon,
                            auctionInfo: AuctionInfo(
                                startPrice: marketItem.currentMinPrice,
                                buyPrice: nil,
                                bidPrice: marketItem.currentMinPrice,
                                endDate: Date(),
                                bidCount: 0,
                                bidStartPrice: marketItem.currentMinPrice
                            ),
                            options: []
                        )
                    }
                    auctionItems.append(contentsOf: newItems)
                    currentPage = nextPage
                case .failure(let error):
                    Logger.error("다음 페이지 로드 실패", error: error)
                }
            }
        }
    }
    
    // 당겨서 새로고침
    private func refreshAuctionData() async {
        guard !apiKey.isEmpty else {
            errorMessage = "API 키가 설정되지 않았습니다. 설정 탭에서 API 키를 입력해주세요."
            showAlert = true
            return
        }
        
        let result = await AuctionService.shared.fetchRelicEngraveBooks(apiKey: apiKey)
        
        await MainActor.run {
            let currentDate = Date()
            onRefresh(currentDate)
            
            switch result {
            case .success(let auction):
                // MarketItem을 AuctionItem으로 변환
                auctionItems = auction.items.map { marketItem in
                    AuctionItem(
                        name: marketItem.name,
                        grade: marketItem.grade,
                        tier: 3,
                        icon: marketItem.icon,
                        auctionInfo: AuctionInfo(
                            startPrice: marketItem.currentMinPrice,
                            buyPrice: nil,
                            bidPrice: marketItem.currentMinPrice,
                            endDate: Date(),
                            bidCount: 0,
                            bidStartPrice: marketItem.currentMinPrice
                        ),
                        options: []
                    )
                }
                
                currentPage = 1
                
                // 페이지네이션 정보 업데이트
                pageSize = auction.pageSize
                totalPages = (auction.totalCount + pageSize - 1) / pageSize
                
                errorMessage = nil
            case .failure(let error):
                errorMessage = error.localizedDescription
                showAlert = true
            }
        }
    }
}

// 악세사리 검색 뷰
struct AccessorySearchView: View {
    var onRefresh: (Date) -> Void
    @AppStorage("apiKey") private var apiKey: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var showAlert = false
    
    // 악세사리 검색 필터 상태
    @State private var selectedEngravings: [String] = []
    @State private var selectedStats: [String] = []
    @State private var selectedQuality: Int = 0
    @State private var searchResults: [AuctionItem] = []
    
    // 각인 및 특성 목록 (실제 구현에서는 API에서 가져오거나 상수로 정의)
    let engraveOptions = [
        "원한", "예리한 둔기", "상급 소환사", "저주받은 인형", "기습의 대가",
        "아드레날린", "정밀 단도", "중갑 착용", "갈증", "타격의 대가"
    ]
    
    let statOptions = ["치명", "특화", "신속", "제압", "인내", "숙련"]
    
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
                        // 각인 선택 섹션
                        SearchFilterSection(title: "각인 선택", isExpanded: true) {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                                ForEach(engraveOptions, id: \.self) { engrave in
                                    FilterChip(
                                        title: engrave,
                                        isSelected: selectedEngravings.contains(engrave),
                                        action: {
                                            toggleSelection(engrave, in: &selectedEngravings)
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 8)
                        }
                        
                        // 특성 선택 섹션
                        SearchFilterSection(title: "특성 선택", isExpanded: true) {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
                                ForEach(statOptions, id: \.self) { stat in
                                    FilterChip(
                                        title: stat,
                                        isSelected: selectedStats.contains(stat),
                                        action: {
                                            toggleSelection(stat, in: &selectedStats)
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 8)
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
                        .disabled(selectedEngravings.isEmpty && selectedStats.isEmpty)
                        
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
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 50))
                                    .foregroundColor(.gray)
                                    .padding()
                                
                                Text("검색 조건을 설정하고 검색 버튼을 눌러주세요")
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
                .disabled(selectedEngravings.isEmpty && selectedStats.isEmpty && selectedQuality == 0)
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
    
    // 선택 토글 헬퍼 함수
    private func toggleSelection(_ item: String, in array: inout [String]) {
        if let index = array.firstIndex(of: item) {
            array.remove(at: index)
        } else {
            array.append(item)
        }
    }
    
    // 검색 필터 초기화
    private func clearFilters() {
        selectedEngravings = []
        selectedStats = []
        selectedQuality = 0
        searchResults = []
    }
    
    // 실제 검색 수행 (API 호출)
    private func performSearch() {
        // 검색 조건이 선택되지 않은 경우
        if selectedEngravings.isEmpty && selectedStats.isEmpty {
            errorMessage = "검색 조건을 하나 이상 선택해주세요"
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
        
        // 이 부분에서 실제 API 호출을 구현해야 합니다.
        // 아래는 예시 코드입니다.
        
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
        
        for i in 1...5 {
            let engrave1 = selectedEngravings.isEmpty ?
                engraveOptions.randomElement()! :
                selectedEngravings.randomElement()!
            
            let engrave2 = engraveOptions.filter { $0 != engrave1 }.randomElement()!
            
            let stat1 = selectedStats.isEmpty ?
                statOptions.randomElement()! :
                selectedStats.randomElement()!
            
            let stat2 = statOptions.filter { $0 != stat1 }.randomElement()!
            
            let quality = max(selectedQuality, Int.random(in: selectedQuality...100))
            
            let options = [
                ItemOption(
                    type: "ABILITY_ENGRAVE",
                    optionName: engrave1,
                    value: Double(Int.random(in: 3...5)),
                    isPenalty: false
                ),
                ItemOption(
                    type: "ABILITY_ENGRAVE",
                    optionName: engrave2,
                    value: Double(Int.random(in: 3...5)),
                    isPenalty: false
                )
            ]
            
            let item = AuctionItem(
                name: "유물 \(stat1)/\(stat2) 목걸이",
                grade: "유물",
                tier: 3,
                icon: "https://cdn-lostark.game.onstove.com/efui_iconatlas/acc_necklace.png",
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
        
        return results
    }
}

// 악세사리 검색 결과 행 컴포넌트
struct AccessoryResultRow: View {
    var item: AuctionItem
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: item.icon)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                Image(systemName: "diamond.fill")
                    .foregroundColor(.orange)
            }
            .frame(width: 40, height: 40)
            .background(Color.black.opacity(0.05))
            .cornerRadius(6)
            
            // 아이템 정보
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                
                // 각인 정보
                ForEach(item.options, id: \.optionName) { option in
                    HStack(spacing: 4) {
                        Text(option.optionName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("+\(Int(option.value))")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .fontWeight(.bold)
                    }
                }
            }
            
            Spacer()
            
            // 가격 정보
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(item.auctionInfo.bidStartPrice.formattedGold) G")
                    .font(.headline)
                    .foregroundColor(.orange)
            }
        }
        .padding(.vertical, 8)
    }
}

// 보석 시세 조회 뷰
struct GemPriceView: View {
    var onRefresh: (Date) -> Void
    @AppStorage("apiKey") private var apiKey: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var showAlert = false
    
    // 보석 필터 상태
    @State private var selectedGemLevel = 7
    @State private var selectedType = 0 // 0: 전체, 1: 멸화, 2: 홍염
    @State private var gemResults: [AuctionItem] = []
    
    // 보석 레벨 선택 옵션
    let gemLevels = [5, 6, 7, 8, 9, 10]
    
    var body: some View {
        VStack {
            if isLoading {
                // 로딩 화면
                ProgressView("보석 시세 불러오는 중...")
                    .padding()
            } else if let error = errorMessage {
                // 에러 화면
                ErrorView(message: error) {
                    // 재시도 버튼 액션
                    loadGemData()
                }
            } else {
                // 보석 필터 섹션
                VStack(spacing: 16) {
                    // 보석 레벨 선택
                    HStack {
                        Text("보석 레벨:")
                            .font(.headline)
                        
                        Spacer()
                        
                        ForEach(gemLevels, id: \.self) { level in
                            Button(action: { selectedGemLevel = level }) {
                                Text("\(level)")
                                    .font(.headline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(selectedGemLevel == level ? Color.blue : Color.gray.opacity(0.2))
                                    .foregroundColor(selectedGemLevel == level ? .white : .primary)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // 보석 타입 선택
                    Picker("보석 타입", selection: $selectedType) {
                        Text("전체").tag(0)
                        Text("멸화").tag(1)
                        Text("홍염").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    Divider()
                    
                    if gemResults.isEmpty {
                        VStack {
                            Button(action: loadGemData) {
                                Text("보석 시세 불러오기")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .cornerRadius(10)
                            }
                            .padding(.horizontal)
                            
                            Spacer()
                                .frame(height: 50)
                            
                            Text("보석 시세 데이터가 없습니다\n보석 시세 불러오기 버튼을 눌러주세요")
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                                .padding()
                        }
                    } else {
                        // 결과 목록
                        List {
                            ForEach(filteredGemResults) { item in
                                GemResultRow(item: item)
                            }
                        }
                        .listStyle(PlainListStyle())
                        .refreshable {
                            await refreshGemData()
                        }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: loadGemData) {
                    Label("새로고침", systemImage: "arrow.clockwise")
                }
                .disabled(isLoading)
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("알림"),
                message: Text(errorMessage ?? ""),
                dismissButton: .default(Text("확인"))
            )
        }
        .onAppear {
            loadGemData()
        }
    }
    
    // 선택된 필터에 따라 결과 필터링
    var filteredGemResults: [AuctionItem] {
        gemResults.filter { item in
            // 타입 필터링 (전체인 경우 모두 표시)
            let typeMatch = selectedType == 0 ||
                (selectedType == 1 && item.name.contains("멸화")) ||
                (selectedType == 2 && item.name.contains("홍염"))
            
            return typeMatch
        }
    }
    
    // 보석 데이터 로드
    private func loadGemData() {
        guard !apiKey.isEmpty else {
            errorMessage = "API 키가 설정되지 않았습니다. 설정 탭에서 API 키를 입력해주세요."
            showAlert = true
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // API 호출 시뮬레이션 (실제 구현에서는 실제 API 호출로 대체)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isLoading = false
            let currentDate = Date()
            onRefresh(currentDate)
            
            // 임시 결과 생성 (실제 API 응답으로 대체 필요)
            self.gemResults = self.generateSampleGemResults()
        }
    }
    
    // 당겨서 새로고침
    private func refreshGemData() async {
        guard !apiKey.isEmpty else {
            errorMessage = "API 키가 설정되지 않았습니다. 설정 탭에서 API 키를 입력해주세요."
            showAlert = true
            return
        }
        
        // 비동기 데이터 로드 시뮬레이션
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        
        await MainActor.run {
            let currentDate = Date()
            onRefresh(currentDate)
            gemResults = generateSampleGemResults()
        }
    }
    
    // 샘플 보석 데이터 생성 (실제 구현 시 제거)
    private func generateSampleGemResults() -> [AuctionItem] {
        var results: [AuctionItem] = []
        
        // 보석 스킬 목록
        let melGemSkills = ["블레이드 블러드", "마운틴 크래쉬", "도끼 스톰", "역습", "스핀 커터", "소울 이터", "초월 구슬"]
        let honGemSkills = ["대지 강타", "차지 스팅어", "데스 칼라", "천벌", "블루 홀", "배쉬", "엘리멘탈 슬래쉬"]
        
        // 멸화 보석 추가
        for skill in melGemSkills {
            let options = [
                ItemOption(
                    type: "GEM_EFFECT",
                    optionName: "\(skill)의 피해 증가",
                    value: Double(selectedGemLevel * 3),
                    isPenalty: false
                )
            ]
            
            let item = AuctionItem(
                name: "레벨 \(selectedGemLevel) 멸화의 보석",
                grade: "고대",
                tier: 3,
                icon: "https://cdn-lostark.game.onstove.com/efui_iconatlas/gem_red.png",
                auctionInfo: AuctionInfo(
                    startPrice: (selectedGemLevel == 7) ? Int.random(in: 1500...2500) * 100 :
                               (selectedGemLevel == 8) ? Int.random(in: 4000...6000) * 100 :
                               (selectedGemLevel == 9) ? Int.random(in: 12000...18000) * 100 :
                               (selectedGemLevel == 10) ? Int.random(in: 35000...50000) * 100 :
                               Int.random(in: 500...1000) * 100,
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
        
        // 홍염 보석 추가
        for skill in honGemSkills {
            let options = [
                ItemOption(
                    type: "GEM_EFFECT",
                    optionName: "\(skill)의 재사용 대기시간 감소",
                    value: Double(selectedGemLevel * 2),
                    isPenalty: false
                )
            ]
            
            let item = AuctionItem(
                name: "레벨 \(selectedGemLevel) 홍염의 보석",
                grade: "고대",
                tier: 3,
                icon: "https://cdn-lostark.game.onstove.com/efui_iconatlas/gem_blue.png",
                auctionInfo: AuctionInfo(
                    startPrice: (selectedGemLevel == 7) ? Int.random(in: 1500...2500) * 100 :
                               (selectedGemLevel == 8) ? Int.random(in: 4000...6000) * 100 :
                               (selectedGemLevel == 9) ? Int.random(in: 12000...18000) * 100 :
                               (selectedGemLevel == 10) ? Int.random(in: 35000...50000) * 100 :
                               Int.random(in: 500...1000) * 100,
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
        
        // 가격순 정렬
        return results.sorted { $0.auctionInfo.bidStartPrice < $1.auctionInfo.bidStartPrice }
    }
}

// 보석 결과 행 컴포넌트
struct GemResultRow: View {
    var item: AuctionItem
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: item.icon)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                Image(systemName: "circle.hexagongrid.fill")
                    .foregroundColor(item.name.contains("멸화") ? .red : .blue)
            }
            .frame(width: 40, height: 40)
            .background(Color.black.opacity(0.05))
            .cornerRadius(6)
            
            // 보석 정보
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                
                // 보석 효과
                if let effect = item.options.first {
                    HStack(spacing: 4) {
                        Text(effect.optionName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(Int(effect.value))%")
                            .font(.caption)
                            .foregroundColor(item.name.contains("멸화") ? .red : .blue)
                            .fontWeight(.bold)
                    }
                }
            }
            
            Spacer()
            
            // 가격 정보
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(item.auctionInfo.startPrice.formattedGold) G")
                    .font(.headline)
                    .foregroundColor(.orange)
            }
        }
        .padding(.vertical, 8)
    }
}

// 검색 필터 섹션 컴포넌트
struct SearchFilterSection<Content: View>: View {
    var title: String
    @State var isExpanded: Bool
    @ViewBuilder var content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Text(title)
                        .font(.headline)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.gray)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal)
            
            if isExpanded {
                content
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(10)
        .padding(.horizontal)
    }
}

// 필터 칩 컴포넌트
struct FilterChip: View {
    var title: String
    var isSelected: Bool
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
    }
}

// 에러 뷰 컴포넌트
struct ErrorView: View {
    var message: String
    var retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("데이터를 불러올 수 없습니다")
                .font(.headline)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: retryAction) {
                Text("다시 시도")
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding(.top, 8)
        }
        .padding()
    }
}
// 경매 아이템 행
struct AuctionItemRow: View {
    var item: AuctionItem
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: item.icon)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                Image(systemName: "book.fill")
                    .foregroundColor(.orange)
            }
            .frame(width: 40, height: 40)
            .background(Color.black.opacity(0.05))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.red.opacity(0.7), lineWidth: 2)
            )
            
            // 아이템 정보
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                
                // 각인 정보
                let engraveInfo = item.engraveInfo
                if !engraveInfo.isEmpty {
                    ForEach(Array(engraveInfo.keys.sorted()), id: \.self) { key in
                        if let value = engraveInfo[key] {
                            HStack(spacing: 4) {
                                Text(key)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text("+\(Int(value))")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                    .fontWeight(.bold)
                            }
                        }
                    }
                }
            }
            
            Spacer()
            
            // 가격 정보
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(item.auctionInfo.bidStartPrice.formattedGold) G")
                    .font(.headline)
                    .foregroundColor(.orange)
            }
        }
        .padding(.vertical, 4)
    }
}
