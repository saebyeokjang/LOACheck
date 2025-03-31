//
//  AuctionService.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 3/26/25.
//

import Foundation

// MARK: - 경매장 옵션 모델
struct MarketOption: Decodable {
    let maxItemLevel: Int
    let itemGradeQualities: [Int]
    let categories: [Category]
    let itemGrades: [String]
    let itemTiers: [Int]
    let classes: [String]
    
    private enum CodingKeys: String, CodingKey {
        case maxItemLevel = "MaxItemLevel"
        case itemGradeQualities = "ItemGradeQualities"
        case categories = "Categories"
        case itemGrades = "ItemGrades"
        case itemTiers = "ItemTiers"
        case classes = "Classes"
    }
    
    struct Category: Decodable {
        let subs: [CategoryItem]
        let code: Int
        let codeName: String
        
        private enum CodingKeys: String, CodingKey {
            case subs = "Subs"
            case code = "Code"
            case codeName = "CodeName"
        }
    }
    
    struct CategoryItem: Decodable {
        let code: Int
        let codeName: String
        
        private enum CodingKeys: String, CodingKey {
            case code = "Code"
            case codeName = "CodeName"
        }
    }
}

// MARK: - 경매장 요청 모델
struct RequestMarketItems: Encodable {
    let categoryCode: Int
    let itemTier: Int?
    let itemGrade: String
    let pageNo: Int
    let sortCondition: String
    let sort: String
    
    private enum CodingKeys: String, CodingKey {
        case categoryCode = "CategoryCode"
        case itemTier = "ItemTier"
        case itemGrade = "ItemGrade"
        case pageNo = "PageNo"
        case sortCondition = "SortCondition"
        case sort = "Sort"
    }
}

// MARK: - 경매장 응답 모델
struct Auction: Decodable {
    let pageNo: Int
    let pageSize: Int
    let totalCount: Int
    let items: [AuctionItem]?
    
    private enum CodingKeys: String, CodingKey {
        case pageNo = "PageNo"
        case pageSize = "PageSize"
        case totalCount = "TotalCount"
        case items = "Items"
    }
}

// MARK: - 경매장 아이템 모델
struct AuctionItem: Decodable, Identifiable {
    var id: String { name + "\(auctionInfo.bidStartPrice)" } // 임시 ID 생성
    let name: String
    let grade: String
    let tier: Int
    let icon: String
    let auctionInfo: AuctionInfo
    let options: [ItemOption]
    
    private enum CodingKeys: String, CodingKey {
        case name = "Name"
        case grade = "Grade"
        case tier = "Tier"
        case icon = "Icon"
        case auctionInfo = "AuctionInfo"
        case options = "Options"
    }
    
    // 계산 속성 - 각인 이름과 수치 쌍 추출
    var engraveInfo: [String: Double] {
        var result: [String: Double] = [:]
        for option in options {
            if option.type == "ABILITY_ENGRAVE" {
                result[option.optionName] = option.value
            }
        }
        return result
    }
    
    // 계산 속성 - 각인 종류
    var engraveName: String {
        return options.first(where: { $0.type == "ABILITY_ENGRAVE" })?.optionName ?? "알 수 없음"
    }
    
    // 계산 속성 - 각인 수치
    var engraveValue: Int {
        if let value = options.first(where: { $0.type == "ABILITY_ENGRAVE" })?.value {
            return Int(value)
        }
        return 0
    }
}

// MARK: - 경매 정보 모델
struct AuctionInfo: Decodable {
    let startPrice: Int
    let buyPrice: Int?
    let bidPrice: Int
    let endDate: Date
    let bidCount: Int
    let bidStartPrice: Int
    
    private enum CodingKeys: String, CodingKey {
        case startPrice = "StartPrice"
        case buyPrice = "BuyPrice"
        case bidPrice = "BidPrice"
        case endDate = "EndDate"
        case bidCount = "BidCount"
        case bidStartPrice = "BidStartPrice"
    }
}

// MARK: - 아이템 옵션 모델
struct ItemOption: Decodable {
    let type: String
    let optionName: String
    let value: Double
    let isPenalty: Bool
    
    private enum CodingKeys: String, CodingKey {
        case type = "Type"
        case optionName = "OptionName"
        case value = "Value"
        case isPenalty = "IsPenalty"
    }
}

// MARK: - 경매장 서비스
class AuctionService {
    static let shared = AuctionService()
    
    private init() {}
    
    private let baseURL = "https://developer-lostark.game.onstove.com"
    private var auctionCategories: [MarketOption.Category] = []
    private var engraveBookCategoryCode: Int = 40000 // 기본값 (실제 코드는 API로 가져옴)
    
    // 유물 전투 각인서 가져오기
    func fetchRelicEngraveBooks(apiKey: String, page: Int = 1) async -> Result<MarketResponse, APIError> {
        do {
            let url = URL(string: "\(baseURL)/markets/items")!
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "accept")
            request.addValue("application/json", forHTTPHeaderField: "content-type")
            request.addValue("bearer \(apiKey)", forHTTPHeaderField: "authorization")
            
            // 요청 본문 구성
            let requestBody: [String: Any] = [
                "Sort": "CURRENT_MIN_PRICE",
                "CategoryCode": 40000,
                "ItemGrade": "유물",
                "PageNo": page,
                "SortCondition": "DESC"
            ]
            
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
            request.httpBody = jsonData
            
            Logger.debug("거래소 아이템 API 요청: \(url.absoluteString)")
            Logger.debug("요청 본문: \(String(data: jsonData, encoding: .utf8) ?? "")")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(.invalidResponse)
            }
            
            let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
            Logger.debug("API 전체 응답: \(responseString)")
            
            switch httpResponse.statusCode {
            case 200:
                let decoder = JSONDecoder()
                let marketResponse = try decoder.decode(MarketResponse.self, from: data)
                
                Logger.debug("성공적으로 \(marketResponse.items.count)개의 거래소 아이템을 디코딩했습니다")
                
                return .success(marketResponse)
                
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
            Logger.error("거래소 아이템 API 오류", error: error)
            return .failure(.networkError(error))
        }
    }
}

// MARK: - 거래소 아이템 모델
struct MarketItem: Decodable, Identifiable {
    let id: Int
    let name: String
    let grade: String
    let icon: String
    let bundleCount: Int
    let tradeRemainCount: Int
    let yesterdayAvgPrice: Double
    let recentPrice: Int
    let currentMinPrice: Int
    
    private enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case grade = "Grade"
        case icon = "Icon"
        case bundleCount = "BundleCount"
        case tradeRemainCount = "TradeRemainCount"
        case yesterdayAvgPrice = "YDayAvgPrice"
        case recentPrice = "RecentPrice"
        case currentMinPrice = "CurrentMinPrice"
    }
}

// MARK: - 거래소 응답 모델
struct MarketResponse: Decodable {
    let pageNo: Int
    let pageSize: Int
    let totalCount: Int
    let items: [MarketItem]
    
    private enum CodingKeys: String, CodingKey {
        case pageNo = "PageNo"
        case pageSize = "PageSize"
        case totalCount = "TotalCount"
        case items = "Items"
    }
}
