//
//  Extensions.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 3/20/25.
//

import Foundation
import SwiftUI

// UserDefaults 확장
extension UserDefaults {
    func string(forHTTPHeaderField field: String) -> String? {
        return string(forKey: field)
    }
}

// View 확장
extension View {
    // SafeArea의 크기를 가져오는 modifier
    func safeAreaInsets(_ perform: @escaping (EdgeInsets) -> Void) -> some View {
        self.background(
            GeometryReader { geometry in
                Color.clear.onAppear {
                    perform(geometry.safeAreaInsets)
                }
            }
        )
    }
    
    // NavigationDestination 추가 (iOS 15 호환)
    func navigationDestination<Destination: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder destination: @escaping () -> Destination
    ) -> some View {
        self.background(
            NavigationLink(
                isActive: isPresented,
                destination: { destination() },
                label: { EmptyView() }
            )
            .opacity(0)
        )
    }
}

// 이미지 비동기 로딩을 위한 확장 (iOS 14 호환)
@available(iOS, deprecated: 15.0, message: "Use AsyncImage")
struct ProxyAsyncImage<Content: View, Placeholder: View>: View {
    private let url: URL?
    private let scale: CGFloat
    private let transaction: Transaction
    private let content: (Image) -> Content
    private let placeholder: () -> Placeholder

    @State private var image: UIImage?
    @State private var isLoading = false

    init(url: URL?, scale: CGFloat = 1.0, transaction: Transaction = Transaction(), @ViewBuilder content: @escaping (Image) -> Content, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.url = url
        self.scale = scale
        self.transaction = transaction
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        if let image = image {
            content(Image(uiImage: image))
        } else {
            placeholder()
                .onAppear {
                    loadImage()
                }
        }
    }

    private func loadImage() {
        guard let url = url, !isLoading else { return }
        isLoading = true
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            isLoading = false
            if let data = data, let uiImage = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.image = uiImage
                }
            }
        }.resume()
    }
}

// 날짜 포맷 확장
extension Date {
    // 날짜를 "yyyy-MM-dd HH:mm" 형식으로 반환
    func formatted() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: self)
    }
    
    // 오늘 날짜인지 확인
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }
    
    // 이번 주 날짜인지 확인
    var isThisWeek: Bool {
        Calendar.current.isDate(self, equalTo: Date(), toGranularity: .weekOfYear)
    }
}

// 색상 확장
extension Color {
    static let lostarkBlue = Color(red: 0.0, green: 0.6, blue: 0.8)
    static let lostarkGold = Color(red: 1.0, green: 0.8, blue: 0.0)
}
