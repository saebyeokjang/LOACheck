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
        var type: String
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
                APIErrorView(message: error) {
                    // 재시도 버튼 액션
                    loadAllGemPrices()
                }
            } else {
                if gemPrices.isEmpty {
                    VStack(spacing: 20) {
                        Spacer()
                        
                        ProgressView("보석 시세 불러오는 중...")
                            .padding()
                        
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
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("알림"),
                message: Text(errorMessage ?? ""),
                dismissButton: .default(Text("확인"))
            )
        }
        // 뷰가 나타날 때 자동으로 데이터 로드
        .onAppear {
            // 데이터가 없는 경우에만 로드 시작
            if gemPrices.isEmpty && !isLoading {
                loadAllGemPrices()
            }
        }
    }
    
    private func loadAllGemPrices() {
        guard !apiKey.isEmpty else {
            errorMessage = "API 키가 설정되지 않았습니다. 설정 탭에서 API 키를 입력해주세요."
            return
        }
        
        isLoading = true
        errorMessage = nil
        gemPrices = []
        
        Task {
            // 일단 하나의 보석만 시도해서 API 상태 확인
            let testResult = await fetchGemPrice(level: gemLevels[0], type: gemTypes[0])
            
            switch testResult {
            case .failure(let error):
                // 첫 번째 요청이 실패하면 API 상태에 문제가 있는 것으로 간주
                if let apiError = error as? APIError {
                    await MainActor.run {
                        isLoading = false
                        errorMessage = apiError.userFriendlyMessage
                    }
                    return
                } else {
                    // 첫 번째 요청에서 일반 오류 발생 - 로깅만 하고 계속 진행
                    Logger.error("API 초기 점검 실패: \(error.localizedDescription)")
                }
            default:
                break // 성공하면 계속 진행
            }
            
            // 병렬 요청 시작
            await withTaskGroup(of: Result<GemPrice?, Error>.self) { group in
                for level in gemLevels {
                    for type in gemTypes {
                        // 첫 번째 요청은 이미 수행했으므로 건너뛰기
                        if level == gemLevels[0] && type == gemTypes[0] {
                            if case .success(let price) = testResult, let price = price {
                                await MainActor.run {
                                    gemPrices.append(price)
                                }
                            }
                            continue
                        }
                        
                        group.addTask {
                            return await fetchGemPrice(level: level, type: type)
                        }
                    }
                }
                
                var errorOccurred = false
                var lastError: Error? = nil
                
                for await result in group {
                    switch result {
                    case .success(let price):
                        if let price = price {
                            await MainActor.run {
                                gemPrices.append(price)
                            }
                        }
                    case .failure(let error):
                        errorOccurred = true
                        lastError = error
                        Logger.error("보석 시세 로드 실패: \(error.localizedDescription)")
                    }
                }
                
                // 결과 처리
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
                    
                    if gemPrices.isEmpty {
                        if let error = lastError as? APIError {
                            errorMessage = error.userFriendlyMessage
                        } else {
                            errorMessage = "보석 시세 정보를 가져올 수 없습니다. 다시 시도해 주세요."
                        }
                    } else if errorOccurred {
                        // 일부 결과만 로드됨 - 사용자에게 알리되 결과는 표시
                        // 여기서는 알림을 표시하지 않고 일부 결과만 표시
                        Logger.debug("일부 보석 시세만 로드됨: \(gemPrices.count)/\(gemLevels.count * gemTypes.count)")
                    }
                }
            }
        }
    }
    
    // 단일 보석 시세 가져오기
    private func fetchGemPrice(level: Int, type: String) async -> Result<GemPrice?, Error> {
        // 보석의 정확한 검색명 형식: "[레벨]레벨 [타입]의 보석"
        let gemSearchName = "\(level)레벨 \(type)의 보석"
        
        // API 요청 보내기
        let result = await fetchGemsWithCustomParams(
            apiKey: apiKey,
            params: [
                "Sort": "CURRENT_MIN_PRICE",
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
            if let items = auction.items, !items.isEmpty {
                if let item = items.first(where: { $0.auctionInfo.buyPrice != nil }) {
                    // 즉시구매가 사용
                    return .success(GemPrice(
                        level: level,
                        type: type,
                        name: item.name,
                        icon: item.icon,
                        price: item.auctionInfo.buyPrice ?? 0
                    ))
                } else if let item = items.first {
                    // 즉시구매가 없는 경우 입찰가 사용
                    return .success(GemPrice(
                        level: level,
                        type: type,
                        name: item.name,
                        icon: item.icon,
                        price: item.auctionInfo.bidStartPrice
                    ))
                }
            }
            // 아이템 배열이 null이거나 비어있는 경우
            return .success(nil)
            
        case .failure(let error):
            Logger.error("보석 시세 가져오기 오류: \(error.localizedDescription)")
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
            
            // 응답 내용 로깅 (디버깅용)
#if DEBUG
            if let responseText = String(data: data, encoding: .utf8) {
                let preview = String(responseText.prefix(200)) // 응답의 앞부분만 로깅
                Logger.debug("API 응답 미리보기: \(preview)")
            }
#endif
            
            switch httpResponse.statusCode {
            case 200:
                // 서비스가 점검 중일 때도 200 상태 코드를 반환하는 경우 점검 메시지 확인
                if let responseText = String(data: data, encoding: .utf8) {
                    if responseText.contains("점검") || responseText.contains("maintenance") {
                        return .failure(.serviceUnavailable)
                    }
                    
                    // 응답이 HTML 형식일 경우 (API가 웹 페이지를 반환하는 경우)
                    if responseText.contains("<html") || responseText.contains("<!DOCTYPE") {
                        Logger.error("API가 HTML 응답을 반환함: \(responseText.prefix(100))")
                        return .failure(.serviceUnavailable)
                    }
                }
                
                // 먼저 JSON 형식인지 확인
                if let _ = try? JSONSerialization.jsonObject(with: data) {
                    let decoder = JSONDecoder()
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
                    decoder.dateDecodingStrategy = .formatted(dateFormatter)
                    
                    // 디코딩 시도
                    do {
                        let auction = try decoder.decode(Auction.self, from: data)
                        return .success(auction)
                    } catch {
                        // 구체적인 디코딩 오류 확인
                        Logger.error("JSON 디코딩 오류 상세: \(error)")
                        
                        // DecodingError의 경우 더 구체적인 오류 정보 로깅
                        if let decodingError = error as? DecodingError {
                            switch decodingError {
                            case .keyNotFound(let key, let context):
                                Logger.error("필수 키를 찾을 수 없음: \(key.stringValue), 경로: \(context.codingPath)")
                            case .typeMismatch(let type, let context):
                                Logger.error("타입 불일치: 예상 타입 \(type), 경로: \(context.codingPath)")
                            case .valueNotFound(let type, let context):
                                Logger.error("값을 찾을 수 없음: 타입 \(type), 경로: \(context.codingPath)")
                            case .dataCorrupted(let context):
                                Logger.error("데이터 손상: \(context)")
                            @unknown default:
                                Logger.error("알 수 없는 디코딩 오류: \(decodingError)")
                            }
                        }
                        
                        // JSON 구조 확인 (디버깅용)
                        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            Logger.debug("JSON 응답 구조: \(json.keys)")
                        }
                        
                        // 오류 메시지가 있는지 확인
                        if let errorDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let message = errorDict["Message"] as? String {
                            Logger.error("API 오류 메시지: \(message)")
                            
                            // 점검 관련 메시지인지 확인
                            if message.contains("점검") || message.contains("maintenance") {
                                return .failure(.serviceUnavailable)
                            }
                        }
                        
                        return .failure(.networkError(error))
                    }
                } else {
                    Logger.error("API 응답이 유효한 JSON 형식이 아님")
                    return .failure(.invalidResponse)
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
                if httpResponse.statusCode >= 500 {
                    // 500번대 오류는 서버 오류이므로 서비스 불가능으로 처리
                    return .failure(.serviceUnavailable)
                }
                return .failure(.unknown(httpResponse.statusCode))
            }
        } catch {
            Logger.error("API 요청 중 오류 발생: \(error)")
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
