//
//  AuctionView.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 3/26/25.
//

import SwiftUI

struct AuctionView: View {
    @AppStorage("apiKey") private var apiKey: String = ""
    @State private var auctionItems: [AuctionItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var showAlert = false
    @State private var lastRefreshedTime: Date? = nil
    @State private var searchText = ""
    @State private var currentPage = 1
    @State private var totalPages = 1
    @State private var isPaginating = false
    
    // 페이지 크기 (API 응답에서 가져옴)
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
        NavigationStack {
            VStack {
                // 마지막 갱신 시간
                HStack {
                    Spacer()
                    
                    if let lastRefreshed = lastRefreshedTime {
                        Text("마지막 갱신: \(lastRefreshed.formatted(date: .omitted, time: .shortened))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                
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
                            .background(Color.white) // 배경색 추가
                            .listRowSeparator(.hidden) // 구분선 숨김
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 20, trailing: 0))
                        }
                    }
                    .listStyle(PlainListStyle())
                    .refreshable {
                        await refreshAuctionData()
                    }
                }
            }
            //.searchable(text: $searchText, prompt: "각인서 이름 검색")
            .navigationTitle("유물 각인서 시세")
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
                lastRefreshedTime = Date()
                
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
            lastRefreshedTime = Date()
            
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
