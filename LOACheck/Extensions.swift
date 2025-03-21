//
//  Extensions.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 3/20/25.
//

import Foundation
import SwiftUI

// MARK: - Logger
struct Logger {
    static func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        print("[\(fileName):\(line)] \(function) - \(message)")
        #endif
    }
    
    static func error(_ message: String, error: Error? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        if let error = error {
            print("ERROR [\(fileName):\(line)] \(function) - \(message): \(error.localizedDescription)")
        } else {
            print("ERROR [\(fileName):\(line)] \(function) - \(message)")
        }
        #endif
    }
    
    static func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        print("INFO [\(fileName):\(line)] \(function) - \(message)")
        #endif
    }
}

// MARK: - UserDefaults 확장
extension UserDefaults {
    func string(forHTTPHeaderField field: String) -> String? {
        return string(forKey: field)
    }
}

// MARK: - View 확장
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
    
    // Alert 표시를 위한 간편한 확장
    func errorAlert(isPresented: Binding<Bool>, message: String) -> some View {
        self.alert(isPresented: isPresented) {
            Alert(
                title: Text("오류"),
                message: Text(message),
                dismissButton: .default(Text("확인"))
            )
        }
    }
    
    // 로딩 오버레이 표시
    func loadingOverlay(isLoading: Bool, message: String = "로딩 중...") -> some View {
        self.overlay {
            if isLoading {
                ZStack {
                    Color(.systemBackground).opacity(0.7)
                    VStack(spacing: 16) {
                        ProgressView()
                        Text(message)
                            .font(.subheadline)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .shadow(radius: 10)
                }
            }
        }
    }
}

// MARK: - 이미지 비동기 로딩을 위한 확장 (iOS 14 호환)
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
            if let error = error {
                Logger.error("Failed to load image", error: error)
                return
            }
            
            if let data = data, let uiImage = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.image = uiImage
                }
            } else {
                Logger.error("Invalid image data from URL: \(url.absoluteString)")
            }
        }.resume()
    }
}

// MARK: - 날짜 포맷 확장
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
    
    // 요일 한글 표현
    var koreanWeekday: String {
        let weekday = Calendar.current.component(.weekday, from: self)
        switch weekday {
        case 1: return "일"
        case 2: return "월"
        case 3: return "화"
        case 4: return "수"
        case 5: return "목"
        case 6: return "금"
        case 7: return "토"
        default: return ""
        }
    }
    
    // 리셋 날짜 (오늘 06시) 반환
    var resetDate: Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: self)
        components.hour = 6
        components.minute = 0
        components.second = 0
        return calendar.date(from: components) ?? self
    }
    
    // 리셋 이후 시간인지 확인
    var isAfterReset: Bool {
        return self >= self.resetDate
    }
}

// MARK: - 색상 확장
extension Color {
    static let lostarkBlue = Color(red: 0.0, green: 0.6, blue: 0.8)
    static let lostarkGold = Color(red: 1.0, green: 0.8, blue: 0.0)
    
    // 난이도별 색상
    static func difficultyColor(_ difficulty: String) -> Color {
        switch difficulty {
        case "하드":
            return .red
        case "노말":
            return .blue
        case "싱글":
            return .green
        default:
            return .gray
        }
    }
}

// MARK: - String 확장
extension String {
    // 문자열 trim
    var trimmed: String {
        return self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // 빈 문자열인지 확인
    var isBlank: Bool {
        return self.trimmed.isEmpty
    }
}

// MARK: - Int 확장
extension Int {
    // 금액 포맷팅 (1,000)
    var formattedGold: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}
