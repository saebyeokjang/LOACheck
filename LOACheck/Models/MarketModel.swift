//
//  MarketModels.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 3/31/25.
//

import Foundation

// MARK: - 부위 카테고리 상수
enum AccessoryCategory: Int {
    case necklace = 200010  // 목걸이
    case earring = 200020   // 귀걸이
    case ring = 200030      // 반지
    
    var name: String {
        switch self {
        case .necklace: return "목걸이"
        case .earring: return "귀걸이"
        case .ring: return "반지"
        }
    }
}

// MARK: - 연마효과 값 모델
struct EngraveEffectValue {
    let displayValue: String
    let value: Int
    let isPercentage: Bool
}

// MARK: - 연마효과 옵션 코드 맵핑
struct EngraveEffectMapping {
    // 연마효과 코드 맵핑 (각 효과에 해당하는 API 코드 값)
    static let effectCodes: [String: (firstOption: Int, secondOption: Int)] = [
        "추가 피해": (7, 42),
        "적에게 주는 피해 증가": (7, 41),
        "공격력 %": (7, 45),
        "공격력 +": (7, 53),
        "무기 공격력 %": (7, 46),
        "무기 공격력 +": (7, 54),
        "치명타 적중률": (7, 49),
        "치명타 피해": (7, 50)
    ]
    
    // 부위별 카테고리 코드
    static let categoryCodes: [Int] = [
        200010, // 목걸이
        200020, // 귀걸이
        200030  // 반지
    ]
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
