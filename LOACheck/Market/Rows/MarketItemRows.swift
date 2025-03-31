//
//  MarketItemRows.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 3/28/25.
//

import SwiftUI
import SwiftData

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
            .overlay(
                // 품질 표시 - 하단 색상 바
                VStack {
                    Spacer()
                    Text(item.name.contains("%") ? item.name.components(separatedBy: "%").first?.trimmingCharacters(in: .whitespaces) ?? "0" : "0")
                        .font(.system(size: 10))
                        .padding(.vertical, 1)
                        .frame(maxWidth: .infinity)
                        .background(getQualityColor(item.name))
                        .foregroundColor(.white)
                }
                .cornerRadius(6)
            )
            
            // 아이템 정보
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                
                // 연마효과 정보
                ForEach(item.options, id: \.optionName) { option in
                    HStack(spacing: 4) {
                        Text(option.optionName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("+\(Int(option.value))%")
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
    
    // 품질에 따른 색상 반환
    private func getQualityColor(_ name: String) -> Color {
        // 이름에서 품질 추출 (예: "유물 90% 목걸이" -> 90)
        if let qualityStr = name.components(separatedBy: "%").first?.components(separatedBy: " ").last,
           let quality = Int(qualityStr) {
            switch quality {
            case 0..<30: return .red
            case 30..<70: return .blue
            case 70..<90: return .purple
            case 90...100: return Color(red: 1.0, green: 0.5, blue: 0.0) // 오렌지
            default: return .gray
            }
        }
        return .gray
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

// 경매 아이템 행 (각인서 목록용)
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
