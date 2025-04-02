//
//  EngravingBookView.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 3/28/25.
//

import SwiftUI
import SwiftData

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
                APIErrorView(message: error) {
                    loadAuctionData()
                }
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
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("알림"),
                message: Text(errorMessage ?? ""),
                dismissButton: .default(Text("확인"))
            )
        }
        .onAppear {
            if auctionItems.isEmpty && !isLoading {
                loadAuctionData()
            }
        }
    }
    
    // 경매장 데이터 로드
    private func loadAuctionData() {
        guard !apiKey.isEmpty else {
            errorMessage = "API 키가 설정되지 않았습니다. 설정 탭에서 API 키를 입력해주세요."
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
                    }
                case .failure(let error):
                    errorMessage = error.localizedDescription
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
