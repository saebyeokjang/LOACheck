//
//  MarketView.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 3/28/25.
//

import SwiftUI
import SwiftData

struct MarketView: View {
    @AppStorage("lastMarketTab") private var selectedTab = 0
    @State private var lastRefreshedTime: Date? = nil
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 마지막 갱신 시간
                if let lastRefreshed = lastRefreshedTime {
                    HStack {
                        Spacer()
                        Text("마지막 갱신: \(lastRefreshed.formatted(date: .omitted, time: .shortened))")
                            .font(.caption)
                            .foregroundColor(Color.textSecondary)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                
                // 상단 세그먼트 컨트롤
                Picker("시세 종류", selection: $selectedTab) {
                    Text("장신구").tag(0)
                    Text("보석").tag(1)
                    Text("각인서").tag(2)
                }
                .pickerStyle(.segmented)
                .padding()
                
                // 선택된 탭에 따라 다른 뷰 표시
                TabView(selection: $selectedTab) {
                    AccessorySearchView(onRefresh: { date in
                        lastRefreshedTime = date
                    })
                    .tag(0)
                    
                    GemPriceView(onRefresh: { date in
                        lastRefreshedTime = date
                    })
                    .tag(1)
                    
                    EngravingBookView(onRefresh: { date in
                        lastRefreshedTime = date
                    })
                    .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .transition(.opacity)
                .animation(.default, value: selectedTab)
                .background(Color.backgroundPrimary)
            }
            .navigationTitle("시세")
            .background(Color.backgroundPrimary)
        }
    }
}

// 에러 뷰 다크모드 대응
struct APIErrorView: View {
    var message: String
    var retryAction: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
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
                .foregroundColor(Color.textPrimary)
            
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
        .frame(maxWidth: .infinity)
        .background(Color.backgroundPrimary)
    }
}

// 품질 색상 공통 함수 확장
extension View {
    // 품질에 따른 색상 반환
    func getQualityColor(_ quality: Int) -> Color {
        return Color.qualityColor(quality)
    }
}
