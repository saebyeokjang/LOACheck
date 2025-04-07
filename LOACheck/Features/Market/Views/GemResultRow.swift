//
//  GemResultRow.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 3/31/25.
//

import SwiftUI
import SwiftData

// 보석 결과 행 컴포넌트
struct GemResultRow: View {
    var item: AuctionItem
    
    // 보석 이름에서 레벨 추출 (예: "10레벨 겁화의 보석" -> 10)
    private func extractGemLevel() -> Int {
        guard let levelStr = item.name.components(separatedBy: "레벨").first?.trimmingCharacters(in: .whitespaces),
              let level = Int(levelStr) else {
            return 0
        }
        return level
    }
    
    // 보석 레벨에 따른 색상 가져오기
    private func getGemColor() -> Color {
        let level = extractGemLevel()
        switch level {
        case 10:
            return Color.ancientGrade
        case 8...9:
            return Color.relicGrade
        case 5...7:
            return Color.legendaryGrade
        case 3...4:
            return Color.epicGrade
        case 1...2:
            return Color.rareGrade
        default:
            return Color.gray
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // 보석 아이콘
            AsyncImage(url: URL(string: item.icon)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                let isRedGem = item.name.contains("겁화")
                Image(systemName: "circle.hexagongrid.fill")
                    .foregroundColor(isRedGem ? .red : .blue)
            }
            .frame(width: 48, height: 48)
            .background(Color.black.opacity(0.05))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(getGemColor(), lineWidth: 2)
            )
            
            // 보석 이름 (추가)
            Text(item.name)
                .font(.headline)
                .foregroundColor(getGemColor())
            
            Spacer()
            
            // 가격 정보
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(item.auctionInfo.bidStartPrice.formattedGold) G")
                    .font(.headline)
                    .foregroundColor(.orange)
                
                // 거래량이나 추가 정보가 있으면 표시
                if let buyPrice = item.auctionInfo.buyPrice {
                    Text("즉시 구매: \(buyPrice.formattedGold) G")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.vertical, 8)
    }
}
