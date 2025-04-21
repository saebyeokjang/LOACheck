//
//  GemResultRow.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 3/31/25.
//

import SwiftUI
import SwiftData

struct GemResultRow: View {
    var item: AuctionItem
    @Environment(\.colorScheme) private var colorScheme
    
    // 보석 레벨에 따른 색상 결정
    private func getGemColor(level: Int) -> Color {
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
    
    // 보석 이름에서 레벨 추출 (예: "10레벨 겁화의 보석" -> 10)
    private func extractGemLevel() -> Int {
        guard let levelStr = item.name.components(separatedBy: "레벨").first?.trimmingCharacters(in: .whitespaces),
              let level = Int(levelStr) else {
            return 0
        }
        return level
    }
    
    // 보석 타입 확인 (겁화 또는 작열)
    private func isRedGem() -> Bool {
        return item.name.contains("겁화")
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // 보석 아이콘 (레벨별 테두리 색상 적용)
            AsyncImage(url: URL(string: item.icon)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                Image(systemName: "circle.hexagongrid.fill")
                    .foregroundColor(isRedGem() ? .red : .blue)
            }
            .frame(width: 48, height: 48)
            .background(colorScheme == .dark ? Color.black.opacity(0.2) : Color.black.opacity(0.05))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(getGemColor(level: extractGemLevel()), lineWidth: 2)
            )
            
            // 보석 이름 - 다크모드 대응
            Text(item.name)
                .font(.headline)
                .foregroundColor(getGemColor(level: extractGemLevel()))
            
            Spacer()
            
            // 가격 정보 (즉시구매가)
            Text("\(item.auctionInfo.buyPrice ?? item.auctionInfo.bidStartPrice) G")
                .font(.headline)
                .foregroundColor(.orange)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(Color.cardBackground)
        .cornerRadius(8)
    }
}
