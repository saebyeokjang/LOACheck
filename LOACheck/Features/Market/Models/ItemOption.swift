//
//  ItemOption.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 3/31/25.
//

import Foundation

// 아이템 옵션 모델
struct ItemOption: Decodable {
    let type: String
    let optionName: String
    let value: Double
    let isPenalty: Bool
    let isValuePercentage: Bool
    
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
        isPenalty = try container.decode(Bool.self, forKey: .isPenalty)
        isValuePercentage = try container.decode(Bool.self, forKey: .isValuePercentage)
        
        // Value 필드 디코딩 - 문자열이나 숫자 모두 처리
        if let stringValue = try? container.decode(String.self, forKey: .value) {
            value = Double(stringValue) ?? 0.0
        } else {
            value = try container.decode(Double.self, forKey: .value)
        }
    }
    
    // 기존 생성자도 유지
    init(type: String, optionName: String, value: Double, isPenalty: Bool, isValuePercentage: Bool = false) {
        self.type = type
        self.optionName = optionName
        self.value = value
        self.isPenalty = isPenalty
        self.isValuePercentage = isValuePercentage
    }
    
    // CodingKeys 추가
    private enum CodingKeys: String, CodingKey {
        case type = "Type"
        case optionName = "OptionName"
        case value = "Value"
        case isPenalty = "IsPenalty"
        case isValuePercentage = "IsValuePercentage"
    }
}
