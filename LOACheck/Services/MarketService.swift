//
//  MarketService.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 3/31/25.
//

import Foundation

class MarketService {
    static let shared = MarketService()
    
    private init() {}
    private let baseURL = "https://developer-lostark.game.onstove.com"
    
    // 장신구 검색 API
    func searchAccessories(
        apiKey: String,
        accessoryType: Int,
        quality: Int,
        engraveEffects: [String],
        engraveValues: [String: Double]
    ) async -> Result<AccessorySearchResponse, APIError> {
        do {
            let url = URL(string: "\(baseURL)/auctions/items")!
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "accept")
            request.addValue("application/json", forHTTPHeaderField: "content-type")
            request.addValue("bearer \(apiKey)", forHTTPHeaderField: "authorization")
            
            // 요청 본문 구성
            var etcOptions: [AccessoryOption] = []
            
            // 선택된 카테고리
            let category = AccessoryCategory(rawValue: [
                AccessoryCategory.necklace.rawValue,
                AccessoryCategory.earring.rawValue,
                AccessoryCategory.ring.rawValue
            ][accessoryType]) ?? .necklace
            
            // 선택된 연마효과를 API 요청 형식으로 변환
            for effect in engraveEffects {
                if let value = engraveValues[effect],
                   let effectCode = EngraveEffectManager.shared.getEngraveEffectCode(effect) {
                    
                    // isPercentage 값 확인
                    let isPercentage = EngraveEffectManager.shared.getEngraveEffectValues(effect)?.first?.isPercentage ?? true
                    
                    // API 요청용 값 계산
                    let apiValue: Int
                    if isPercentage {
                        // 백분율 값인 경우 값을 그대로 사용
                        // (이미 engraveEffectValues에서 적절한 값으로 설정되어 있음)
                        apiValue = Int(value)
                    } else {
                        // 절대값인 경우 100을 곱하지 않고 값을 그대로 사용
                        apiValue = Int(value)
                    }
                    
                    let option = AccessoryOption(
                        firstOption: 7, // 연마효과 그룹 코드
                        secondOption: effectCode,
                        minValue: apiValue,
                        maxValue: apiValue
                    )
                    etcOptions.append(option)
                }
            }
            
            // 검색 요청 구성
            let requestBody = AccessorySearchRequest(
                itemGradeQuality: quality,
                etcOptions: etcOptions,
                sort: "BIDSTART_PRICE",
                categoryCode: category.rawValue,
                itemTier: 4,
                itemGrade: "고대",
                sortCondition: "ASC"
            )
            
            let encoder = JSONEncoder()
            let jsonData = try encoder.encode(requestBody)
            request.httpBody = jsonData
            
            Logger.debug("장신구 검색 API 요청: \(url.absoluteString)")
            Logger.debug("요청 본문: \(String(data: jsonData, encoding: .utf8) ?? "")")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(.invalidResponse)
            }
            
            // 응답 헤더 확인 (디버깅용)
            Logger.debug("API 응답 상태 코드: \(httpResponse.statusCode)")
            
            // 응답 크기 확인
            Logger.debug("응답 데이터 크기: \(data.count) 바이트")
            
            // 응답 내용 샘플 로깅 (첫 1000자만)
            if let responsePreview = String(data: data.prefix(1000), encoding: .utf8) {
                Logger.debug("응답 내용 (일부): \(responsePreview)")
            }
            
            switch httpResponse.statusCode {
            case 200:
                let decoder = JSONDecoder()
                
                do {
                    let searchResponse = try decoder.decode(AccessorySearchResponse.self, from: data)
                    Logger.debug("성공적으로 \(searchResponse.items.count)개의 장신구 검색 결과를 디코딩했습니다")
                    
                    // 검색 결과가 없는 경우 적절한 메시지 표시
                    if searchResponse.totalCount == 0 {
                        return .success(searchResponse)  // 빈 배열을 포함한 응답 반환
                    }
                    
                    // 첫 번째 아이템 로깅 (디버깅용)
                    if let firstItem = searchResponse.items.first {
                        Logger.debug("첫 번째 아이템: \(firstItem.name) (품질: \(firstItem.gradeQuality))")
                        Logger.debug("거래 가능 횟수: \(firstItem.auctionInfo.tradeAllowCount)")
                        
                        // 옵션들 로깅
                        for (index, option) in firstItem.options.enumerated() {
                            Logger.debug("옵션 \(index+1): \(option.optionName) = \(option.value) (타입: \(option.type))")
                        } 
                    } else {
                        Logger.debug("검색 결과가 없습니다. (totalCount: \(searchResponse.totalCount))")
                    }
                    
                    return .success(searchResponse)
                } catch {
                    Logger.error("JSON 디코딩 오류", error: error)
                    
                    // 디코딩 오류 상세 정보 로깅
                    if let decodingError = error as? DecodingError {
                        switch decodingError {
                        case .keyNotFound(let key, let context):
                            Logger.debug("키를 찾을 수 없음: \(key), 경로: \(context.codingPath)")
                        case .typeMismatch(let type, let context):
                            Logger.debug("타입 불일치: \(type), 경로: \(context.codingPath)")
                        case .valueNotFound(let type, let context):
                            Logger.debug("값을 찾을 수 없음: \(type), 경로: \(context.codingPath)")
                        case .dataCorrupted(let context):
                            Logger.debug("데이터 손상: \(context)")
                        @unknown default:
                            Logger.debug("알 수 없는 디코딩 오류: \(decodingError)")
                        }
                    }
                    
                    // 디코딩 실패 시, 원본 JSON 구조를 확인하여 디버깅
                    if let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                        Logger.debug("JSON 구조 확인: \(jsonObject)")
                    }
                    
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
            Logger.error("장신구 검색 API 오류", error: error)
            return .failure(.networkError(error))
        }
    }
    
    // 장신구 아이템을 AuctionItem으로 변환 (뷰에서 사용하기 위함)
    func convertToAuctionItems(from accessoryItems: [AccessoryItem]) -> [AuctionItem] {
        return accessoryItems.map { item in
            // 옵션 변환
            let options = item.options.map { option in
                ItemOption(
                    type: option.type,
                    optionName: option.optionName,
                    value: option.value, // 이미 Double 타입으로 변환됨
                    isPenalty: option.isPenalty,
                    isValuePercentage: option.isValuePercentage
                )
            }
            
            // 날짜 변환 - 로스트아크 API 날짜 형식에 맞게 설정
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            
            // 경매 정보 변환
            let auctionInfo = AuctionInfo(
                startPrice: item.auctionInfo.startPrice,
                buyPrice: item.auctionInfo.buyPrice,
                bidPrice: item.auctionInfo.bidPrice,
                endDate: formatter.date(from: item.auctionInfo.endDate) ?? Date(),
                bidCount: item.auctionInfo.bidCount,
                bidStartPrice: item.auctionInfo.bidStartPrice
            )
            
            // AuctionItem 생성
            return AuctionItem(
                name: item.name,
                grade: item.grade,
                tier: item.tier,
                icon: item.icon,
                auctionInfo: auctionInfo,
                options: options,
                quality: item.gradeQuality,
                tradeAllowCount: item.auctionInfo.tradeAllowCount
            )
        }
    }
    
    // 장신구 검색 결과를 간단히 로깅하는 함수 (디버깅용)
    func logSearchResults(_ response: AccessorySearchResponse) {
        Logger.debug("총 \(response.totalCount)개의 검색 결과 중 \(response.items.count)개 로드됨")
        
        for (index, item) in response.items.prefix(2).enumerated() {
            Logger.debug("아이템 \(index+1): \(item.name) (품질: \(item.gradeQuality))")
            Logger.debug("  - 거래 가능 횟수: \(item.auctionInfo.tradeAllowCount)")
            
            let statOptions = item.options.filter { $0.type == "5" || $0.type == "STAT" }
            for stat in statOptions {
                Logger.debug("  - \(stat.optionName): \(stat.value)")
            }
            
            Logger.debug("  - 즉시 구매가: \(item.auctionInfo.buyPrice ?? item.auctionInfo.bidStartPrice)")
        }
    }
}
