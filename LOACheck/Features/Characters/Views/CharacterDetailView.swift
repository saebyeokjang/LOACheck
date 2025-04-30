//
//  CharacterDetailView.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 3/20/25.
//

import SwiftUI
import SwiftData

struct CharacterDetailView: View {
    // 직접 캐릭터 모델을 참조하되 @Bindable 사용
    @Bindable var character: CharacterModel
    var isCurrentlyActive: Bool = true
    @State private var scrollViewID = UUID()
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @AppStorage("apiKey") private var apiKey: String = ""
    @State private var isRefreshing = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    // 페이지 이동 관련 콜백
    var goToPreviousPage: (() -> Void)?
    var goToNextPage: (() -> Void)?
    
    // 캐릭터 유효성 검사 계산 프로퍼티 추가
    private var isValidCharacter: Bool {
        return !character.name.isEmpty && character.level > 0
    }
    
    // 스크롤 위치 추적을 위한 네임스페이스
    private enum ScrollToTop {
        case top
    }
    
    var body: some View {
        // 유효성 검사 추가
        Group {
            if isValidCharacter {
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            // 스크롤 최상단 위치 식별을 위한 빈 뷰
                            Color.clear
                                .frame(height: 0)
                                .id(ScrollToTop.top)
                            
                            // 캐릭터 정보 헤더
                            characterHeaderView()
                            
                            // 일일 숙제 섹션 - 안전한 헬퍼 메소드 사용
                            let safeTasks = character.getSafeDailyTasks()
                            if !safeTasks.isEmpty {
                                DailyTasksView(
                                    tasks: safeTasks,
                                    character: character,
                                    isActiveView: isCurrentlyActive
                                )
                            }
                            
                            // 주간 레이드 섹션 - 다크모드 개선 버전 사용
                            // 안전한 헬퍼 메소드 사용
                            if character.level >= 1370 {
                                WeeklyRaidsView(character: character)
                            }
                            
                            Spacer()
                        }
                        .padding(.bottom, 20)
                    }
                    .id(scrollViewID)
                    .onAppear {
                        // 뷰가 나타날 때 최상단으로 이동 - 지연 추가
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation {
                                proxy.scrollTo(ScrollToTop.top, anchor: .top)
                            }
                        }
                    }
                    .onChange(of: isCurrentlyActive) { _, newValue in
                        if newValue {
                            // 페이지가 활성화될 때 스크롤 위치 재설정 - 지연 추가
                            scrollViewID = UUID()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation {
                                    proxy.scrollTo(ScrollToTop.top, anchor: .top)
                                }
                            }
                        }
                    }
                    // 배경색을 다크모드 대응 색상으로 변경
                    .background(Color.backgroundPrimary)
                }
            } else {
                // 유효하지 않은 캐릭터일 경우 대체 뷰
                VStack {
                    Text("유효하지 않은 캐릭터 정보입니다")
                        .font(.headline)
                        .padding()
                    
                    Button("돌아가기") {
                        goToPreviousPage?()
                    }
                    .padding()
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.backgroundPrimary)
            }
        }
        .alert("알림", isPresented: $showAlert) {
            Button("확인") {}
        } message: {
            Text(alertMessage)
        }
    }
    
    // 캐릭터 헤더 뷰
    @ViewBuilder
    private func characterHeaderView() -> some View {
        VStack(spacing: 12) {
            ZStack(alignment: .topTrailing) {
                // 메인 콘텐츠
                HStack {
                    // 이전 페이지로 이동
                    Button(action: {
                        goToPreviousPage?()
                    }) {
                        Image(systemName: "chevron.left")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .foregroundColor(goToPreviousPage != nil ?
                                             (colorScheme == .dark ? .blue.opacity(0.9) : .blue) :
                                                (colorScheme == .dark ? .gray.opacity(0.7) : .gray))
                            .frame(width: 44, height: 44)
                            .background(Color.clear)
                            .cornerRadius(8)
                    }
                    .disabled(goToPreviousPage == nil)
                    
                    Spacer()
                    
                    VStack(spacing: 8) {
                        Text(character.name)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(Color.textPrimary)
                        
                        Text("\(character.server) • \(character.characterClass)")
                            .font(.subheadline)
                            .foregroundColor(Color.textSecondary)
                        
                        Text("아이템 레벨: \(String(format: "%.2f", character.level))")
                            .font(.headline)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 12)
                            .background(Color.blue.opacity(colorScheme == .dark ? 0.15 : 0.1))
                            .foregroundColor(colorScheme == .dark ? .blue.opacity(0.9) : .blue)
                            .cornerRadius(8)
                        
                        // 골드 획득 캐릭터 표시
                        if character.isGoldEarner {
                            Text("골드 획득 캐릭터")
                                .font(.caption)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .background(Color.yellow.opacity(colorScheme == .dark ? 0.2 : 0.2))
                                .foregroundColor(colorScheme == .dark ? .orange.opacity(0.9) : .orange)
                                .cornerRadius(4)
                        }
                    }
                    
                    Spacer()
                    
                    // 다음 페이지로 이동 버튼
                    Button(action: {
                        goToNextPage?()
                    }) {
                        Image(systemName: "chevron.right")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .foregroundColor(goToNextPage != nil ?
                                            (colorScheme == .dark ? .blue.opacity(0.9) : .blue) :
                                                (colorScheme == .dark ? .gray.opacity(0.7) : .gray))
                            .frame(width: 44, height: 44)
                            .background(Color.clear)
                            .cornerRadius(8)
                    }
                    .disabled(goToNextPage == nil)
                }
            }
            .padding(.horizontal)
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 5, x: 0, y: 2)
    }
    
    // 개별 캐릭터 새로고침 함수 - 개선된 버전
    private func refreshCharacter() {
        guard !apiKey.isEmpty else {
            alertMessage = "API 키가 설정되지 않았습니다. 설정 탭에서 API 키를 입력해주세요."
            showAlert = true
            return
        }
        
        guard !isRefreshing else { return }
        
        isRefreshing = true
        
        Task {
            let result = await LostArkAPIService.shared.updateSingleCharacterViaArmory(
                name: character.name,
                apiKey: apiKey,
                modelContext: modelContext
            )
            
            await MainActor.run {
                isRefreshing = false
                
                switch result {
                case .success:
                    alertMessage = "\(character.name) 캐릭터의 정보가 갱신되었습니다."
                    
                    // 동기화 표시
                    DataSyncManager.shared.markLocalChanges()
                    
                    // 자동 동기화 수행 (로그인 상태 및 네트워크 연결 확인)
                    if AuthManager.shared.isLoggedIn && NetworkMonitorService.shared.isConnected {
                        Task {
                            let success = await DataSyncManager.shared.uploadToServer()
                            Logger.debug("캐릭터 새로고침으로 인한 동기화 결과: \(success ? "성공" : "실패")")
                        }
                    }
                    
                    // 성공 시 NotificationCenter를 통해 갱신 알림 발송
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshCharacterList"), object: nil)
                    
                case .failure(let error):
                    switch error {
                    case .serviceUnavailable:
                        alertMessage = "로스트아크 API 서비스가 현재 점검 중입니다. 나중에 다시 시도해주세요."
                    case .rateLimit:
                        alertMessage = "API 호출 한도를 초과했습니다. 잠시 후 다시 시도해주세요."
                    case .unauthorized:
                        alertMessage = "API 키가 유효하지 않습니다. 설정에서 API 키를 확인해주세요."
                    case .forbidden:
                        alertMessage = "API 접근 권한이 없습니다. 설정에서 API 키를 확인해주세요."
                    case .documentNotFound:
                        alertMessage = "원정대 목록에서 해당 캐릭터를 찾을 수 없습니다."
                    default:
                        alertMessage = "네트워크 오류가 발생했습니다. 인터넷 연결을 확인하고 다시 시도해주세요."
                    }
                }
                
                showAlert = true
            }
        }
    }
}
