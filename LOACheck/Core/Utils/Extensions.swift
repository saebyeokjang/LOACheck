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
    
    // 현대화된 네비게이션 - iOS 18 이상에서는 programmatic navigation 사용
    func modernNavigationDestination<Destination: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder destination: @escaping () -> Destination
    ) -> some View {
        self.modifier(PresentationLinkModifier(isPresented: isPresented, destination: destination))
    }
    
    // Alert 표시를 위한 간편한 확장
    func errorAlert(isPresented: Binding<Bool>, message: String) -> some View {
        self.alert("오류", isPresented: isPresented) {
            Button("확인") { }
        } message: {
            Text(message)
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

// MARK: - 프로그래매틱 네비게이션을 위한 모디파이어
struct PresentationLinkModifier<Destination: View>: ViewModifier {
    @Binding var isPresented: Bool
    let destination: () -> Destination
    @State private var path = NavigationPath()
    
    func body(content: Content) -> some View {
        content
            .onChange(of: isPresented) { _, newValue in
                if newValue {
                    path.append("destination")
                } else if !path.isEmpty {
                    path.removeLast()
                }
            }
            .navigationDestination(for: String.self) { _ in
                destination()
                    .onDisappear {
                        // 뒤로 가기 시 바인딩 업데이트
                        if isPresented {
                            isPresented = false
                        }
                    }
            }
            .environment(\.navigationPath, path)
    }
}

// MARK: - NavigationPath 환경 변수
struct NavigationPathKey: EnvironmentKey {
    static var defaultValue: NavigationPath = NavigationPath()
}

extension EnvironmentValues {
    var navigationPath: NavigationPath {
        get { self[NavigationPathKey.self] }
        set { self[NavigationPathKey.self] = newValue }
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
