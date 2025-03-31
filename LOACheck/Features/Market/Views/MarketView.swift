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
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 마지막 갱신 시간
                if let lastRefreshed = lastRefreshedTime {
                    HStack {
                        Spacer()
                        Text("마지막 갱신: \(lastRefreshed.formatted(date: .omitted, time: .shortened))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                
                // 상단 세그먼트 컨트롤
                Picker("시세 종류", selection: $selectedTab) {
                    Text("악세사리").tag(0)
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
                .tabViewStyle(.page(indexDisplayMode: .never)) // 페이지 인디케이터 숨김
                .animation(.easeInOut, value: selectedTab)
            }
            .navigationTitle("시세 검색")
        }
    }
}

#Preview {
    MarketView()
}
