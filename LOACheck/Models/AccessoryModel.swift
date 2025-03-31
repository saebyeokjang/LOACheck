//
//  AccessoryModel.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 3/31/25.
//

import Foundation

// 실제 API 응답 구조에 맞게 수정된 모델
struct AccessorySearchResponse: Decodable {
    let pageNo: Int
    let pageSize: Int
    let totalCount: Int
    let items: [AccessoryItem]
    
    enum CodingKeys: String, CodingKey {
        case pageNo = "PageNo"
        case pageSize = "PageSize"
        case totalCount = "TotalCount"
        case items = "Items"
    }
}

struct AccessoryItem: Decodable, Identifiable {
    let name: String
    let grade: String
    let tier: Int
    let level: Int
    let icon: String
    let gradeQuality: Int
    let auctionInfo: AccessoryAuctionInfo
    let options: [AccessoryItemOption]
    
    var id: String { UUID().uuidString }
    
    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case grade = "Grade"
        case tier = "Tier"
        case level = "Level"
        case icon = "Icon"
        case gradeQuality = "GradeQuality"
        case auctionInfo = "AuctionInfo"
        case options = "Options"
    }
}

struct AccessoryAuctionInfo: Decodable {
    let startPrice: Int
    let buyPrice: Int?
    let bidPrice: Int
    let endDate: String
    let bidCount: Int
    let bidStartPrice: Int
    let isCompetitive: Bool
    let tradeAllowCount: Int
    let upgradeLevel: Int
    
    enum CodingKeys: String, CodingKey {
        case startPrice = "StartPrice"
        case buyPrice = "BuyPrice"
        case bidPrice = "BidPrice"
        case endDate = "EndDate"
        case bidCount = "BidCount"
        case bidStartPrice = "BidStartPrice"
        case isCompetitive = "IsCompetitive"
        case tradeAllowCount = "TradeAllowCount"
        case upgradeLevel = "UpgradeLevel"
    }
}

struct AccessoryItemOption: Decodable, Identifiable {
    let type: String  // 타입을 문자열로 통일
    let optionName: String
    let optionNameTripod: String
    var value: Double  // 값을 Double로 통일
    let isPenalty: Bool
    let isValuePercentage: Bool
    let className: String?
    
    var id: String { optionName + "\(value)" }
    
    enum CodingKeys: String, CodingKey {
        case type = "Type"
        case optionName = "OptionName"
        case optionNameTripod = "OptionNameTripod"
        case value = "Value"
        case isPenalty = "IsPenalty"
        case className = "ClassName"
        case isValuePercentage = "IsValuePercentage"
    }
    
    // 사용자 정의 디코딩 구현
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Type 필드 디코딩 - 문자열이나 숫자 모두 처리
        if let intType = try? container.decode(Int.self, forKey: .type) {
            type = String(intType)
        } else {
            type = try container.decode(String.self, forKey: .type)
        }
        
        optionName = try container.decode(String.self, forKey: .optionName)
        optionNameTripod = try container.decode(String.self, forKey: .optionNameTripod)
        isPenalty = try container.decode(Bool.self, forKey: .isPenalty)
        isValuePercentage = try container.decode(Bool.self, forKey: .isValuePercentage)
        className = try container.decodeIfPresent(String.self, forKey: .className)
        
        // Value 필드 디코딩 - 문자열이나 숫자 모두 처리
        if let stringValue = try? container.decode(String.self, forKey: .value) {
            value = Double(stringValue) ?? 0.0
        } else {
            value = try container.decode(Double.self, forKey: .value)
        }
    }
    
    // 기존 생성자도 유지
    init(type: String, optionName: String, optionNameTripod: String = "", value: Double, isPenalty: Bool, isValuePercentage: Bool, className: String? = nil) {
        self.type = type
        self.optionName = optionName
        self.optionNameTripod = optionNameTripod
        self.value = value
        self.isPenalty = isPenalty
        self.isValuePercentage = isValuePercentage
        self.className = className
    }
}

// 악세사리 검색 요청 모델
struct AccessorySearchRequest: Encodable {
    let itemGradeQuality: Int
    let etcOptions: [AccessoryOption]
    let sort: String
    let categoryCode: Int
    let itemTier: Int
    let itemGrade: String
    let sortCondition: String
    
    enum CodingKeys: String, CodingKey {
        case itemGradeQuality = "ItemGradeQuality"
        case etcOptions = "EtcOptions"
        case sort = "Sort"
        case categoryCode = "CategoryCode"
        case itemTier = "ItemTier"
        case itemGrade = "ItemGrade"
        case sortCondition = "SortCondition"
    }
}

// 연마효과 옵션
struct AccessoryOption: Encodable {
    let firstOption: Int
    let secondOption: Int
    let minValue: Int
    let maxValue: Int
    
    enum CodingKeys: String, CodingKey {
        case firstOption = "FirstOption"
        case secondOption = "SecondOption"
        case minValue = "MinValue"
        case maxValue = "MaxValue"
    }
}
