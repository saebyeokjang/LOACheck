//
//  GemPriceView.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 3/28/25.
//

import SwiftUI
import SwiftData

struct GemPriceView: View {
    var onRefresh: (Date) -> Void
    @AppStorage("apiKey") private var apiKey: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var showAlert = false
    
    // 보석 가격 저장 구조체
    struct GemPrice: Identifiable {
        var id = UUID()
        var level: Int
        var type: String  // "겁화" 또는 "작열"
        var name: String
        var icon: String
        var price: Int
    }
    
    // 보석 가격 데이터
    @State private var gemPrices: [GemPrice] = []
    
    // 보석 레벨 범위
    let gemLevels = [10, 9, 8, 7, 6, 5]
    let gemTypes = ["겁화", "작열"]
    
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
                    loadAllGemPrices()
                }
            } else {
                if gemPrices.isEmpty {
                    // 데이터가 없는 경우
                    VStack(spacing: 20) {
                        Spacer()
                        
                        Image(systemName: "sparkles")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("보석 시세 데이터가 없습니다")
                            .font(.headline)
                        
                        Button(action: loadAllGemPrices) {
                            Text("보석 시세 불러오기")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal, 40)
                        
                        Spacer()
                    }
                } else {
                    // 보석 시세 목록
                    List {
                        ForEach(gemPrices) { gem in
                            GemPriceRow(gem: gem)
                        }
                    }
                    .listStyle(PlainListStyle())
                    .refreshable {
                        await refreshGemData()
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: loadAllGemPrices) {
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
    
    // 모든 보석 레벨의 시세 로드 (순차적으로 로드하여 네트워크 부하 감소)
    private func loadAllGemPrices() {
        guard !apiKey.isEmpty else {
            errorMessage = "API 키가 설정되지 않았습니다. 설정 탭에서 API 키를 입력해주세요."
            showAlert = true
            return
        }
        
        isLoading = true
        errorMessage = nil
        gemPrices = []
        
        Task {
            // 순차적으로 요청을 보내 네트워크 부하 감소
            for level in gemLevels {
                for type in gemTypes {
                    // 동시 요청을 피하기 위해 각 요청 사이에 작은 딜레이 추가
                    if level != gemLevels.first || type != gemTypes.first {
                        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2초 지연
                    }
                    
                    let result = await fetchGemPrice(level: level, type: type)
                    
                    switch result {
                    case .success(let price):
                        if let price = price {
                            await MainActor.run {
                                gemPrices.append(price)
                            }
                        }
                    case .failure(let error):
                        Logger.error("보석 시세 로드 실패: \(level)레벨 \(type) - \(error.localizedDescription)")
                        // 개별 실패는 무시하고 계속 진행
                    }
                }
            }
            
            // 모든 요청이 완료된 후 업데이트
            await MainActor.run {
                isLoading = false
                let currentDate = Date()
                onRefresh(currentDate)
                
                // 보석 정렬: 레벨 높은 순 -> 종류(겁화 먼저)
                gemPrices.sort { gem1, gem2 in
                    if gem1.level != gem2.level {
                        return gem1.level > gem2.level // 높은 레벨 우선
                    }
                    return gem1.type == "겁화" // 같은 레벨에서는 겁화 우선
                }
                
                // 결과가 없으면 에러 메시지
                if gemPrices.isEmpty {
                    errorMessage = "보석 시세 정보를 가져올 수 없습니다."
                    showAlert = true
                }
            }
        }
    }
    
    // 단일 보석 시세 가져오기
    private func fetchGemPrice(level: Int, type: String) async -> Result<GemPrice?, Error> {
        // 보석의 정확한 검색명 형식: "[레벨]레벨 [타입]의 보석"
        let gemSearchName = "\(level)레벨 \(type)의 보석"
        
        do {
            // API 요청 보내기
            let result = await fetchGemsWithCustomParams(
                apiKey: apiKey,
                params: [
                    "Sort": "BuyPrice",  // 즉시구매가 기준으로 정렬
                    "CategoryCode": 210000,
                    "ItemTier": 4,
                    "ItemName": gemSearchName,
                    "PageNo": 0,
                    "SortCondition": "ASC"
                ]
            )
            
            switch result {
            case .success(let auction):
                // 결과가 있고 즉시구매가가 있는 아이템 찾기
                if let item = auction.items?.first(where: { $0.auctionInfo.buyPrice != nil }) {
                    // 즉시구매가 사용
                    return .success(GemPrice(
                        level: level,
                        type: type,
                        name: item.name,
                        icon: item.icon,
                        price: item.auctionInfo.buyPrice ?? 0
                    ))
                } else if let item = auction.items?.first {
                    // 즉시구매가 없는 경우 입찰가 사용
                    return .success(GemPrice(
                        level: level,
                        type: type,
                        name: item.name,
                        icon: item.icon,
                        price: item.auctionInfo.bidStartPrice
                    ))
                }
                return .success(nil) // 해당 레벨/종류 보석 없음
                
            case .failure(let error):
                return .failure(error)
            }
        } catch {
            return .failure(error)
        }
    }
    
    // 사용자 정의 파라미터로 보석 시세 가져오기
    private func fetchGemsWithCustomParams(apiKey: String, params: [String: Any]) async -> Result<Auction, APIError> {
        do {
            let url = URL(string: "https://developer-lostark.game.onstove.com/auctions/items")!
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "accept")
            request.addValue("application/json", forHTTPHeaderField: "content-type")
            request.addValue("bearer \(apiKey)", forHTTPHeaderField: "authorization")
            request.timeoutInterval = 15  // 15초 타임아웃
            
            let jsonData = try JSONSerialization.data(withJSONObject: params)
            request.httpBody = jsonData
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(.invalidResponse)
            }
            
            switch httpResponse.statusCode {
            case 200:
                let decoder = JSONDecoder()
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
                decoder.dateDecodingStrategy = .formatted(dateFormatter)
                
                do {
                    let auction = try decoder.decode(Auction.self, from: data)
                    return .success(auction)
                } catch {
                    Logger.error("JSON 디코딩 오류", error: error)
                    return .failure(.networkError(error))
                }
                
            case 401:
                return .failure(.unauthorized)
            case 403:
                return .failure(.forbidden)
            case 429:
                return .failure(.rateLimit)
            case 503:
                return .failure(.serviceUnavailable)
            default:
                return .failure(.unknown(httpResponse.statusCode))
            }
        } catch {
            Logger.error("보석 시세 API 오류", error: error)
            return .failure(.networkError(error))
        }
    }
    
    // 당겨서 새로고침
    private func refreshGemData() async {
        guard !isLoading else { return }
        
        await MainActor.run {
            loadAllGemPrices()
        }
    }
}

// 보석 시세 행 컴포넌트
struct GemPriceRow: View {
    var gem: GemPriceView.GemPrice
    
    // 보석 레벨에 따른 색상 결정
    private func getGemColor(level: Int) -> Color {
        switch level {
        case 10:
            return Color.ancientGrade
        case 8...9:
            return Color.relicGrade
        case 5...7:
            return Color.legendaryGrade
        default:
            return Color.gray
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // 보석 아이콘 (레벨별 테두리 색상 적용)
            AsyncImage(url: URL(string: gem.icon)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                let isRedGem = gem.type == "겁화"
                Image(systemName: "circle.hexagongrid.fill")
                    .foregroundColor(isRedGem ? .red : .blue)
            }
            .frame(width: 48, height: 48)
            .background(Color.black.opacity(0.05))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(getGemColor(level: gem.level), lineWidth: 2)
            )
            
            // 보석 이름 - 테두리와 동일한 색상 적용
            Text(gem.name)
                .font(.headline)
                .foregroundColor(getGemColor(level: gem.level))
            
            Spacer()
            
            // 가격 정보 (즉시구매가)
            Text("\(gem.price.formattedGold) G")
                .font(.headline)
                .foregroundColor(.orange)
        }
        .padding(.vertical, 8)
    }
}

// 에러 뷰
struct ErrorView: View {
    var message: String
    var retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text(message)
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding()
            
            Button(action: retryAction) {
                Text("다시 시도")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(width: 200)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            
            Spacer()
        }
    }
}
