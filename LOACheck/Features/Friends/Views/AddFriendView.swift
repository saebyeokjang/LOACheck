//
//  AddFriendView.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 4/8/25.
//

import SwiftUI

struct AddFriendView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var friendsService: FriendsService
    
    @State private var searchCharacterName = ""
    @State private var searchedUser: User?
    @State private var characterDetails: CharacterModel?
    @State private var isSearching = false
    @State private var isLoadingCharDetails = false
    @State private var hasSearched = false
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var shouldDismiss = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // 검색 설명
                VStack(spacing: 12) {
                    Text("친구 추가")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("친구의 캐릭터 이름을 입력하여 검색할 수 있습니다")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)
                
                // 캐릭터 이름 검색 필드
                VStack(alignment: .leading, spacing: 8) {
                    Text("캐릭터 이름")
                        .font(.headline)
                    
                    HStack {
                        TextField("친구 캐릭터 이름 입력", text: $searchCharacterName)
                            .autocapitalization(.none)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        
                        Button(action: searchUser) {
                            Text("검색")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                        .disabled(searchCharacterName.isEmpty || isSearching)
                    }
                }
                .padding(.horizontal)
                
                if isSearching {
                    // 검색 중 로딩 표시
                    ProgressView("검색 중...")
                        .padding()
                } else if hasSearched {
                    if let user = searchedUser {
                        // 검색 결과 표시
                        VStack(spacing: 16) {
                            UserSearchResultView(
                                user: user,
                                characterName: searchCharacterName,
                                characterDetails: characterDetails,
                                isLoading: isLoadingCharDetails
                            ) {
                                sendFriendRequest(to: searchCharacterName)
                            }
                        }
                        .padding()
                    } else {
                        // 검색 결과 없음
                        VStack(spacing: 12) {
                            Image(systemName: "person.slash")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                            
                            Text("캐릭터를 찾을 수 없습니다")
                                .font(.headline)
                            
                            Text("캐릭터 이름을 확인하고 다시 시도하세요")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    }
                }
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("닫기") {
                        dismiss()
                    }
                }
            }
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text(alertTitle),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("확인")) {
                        if shouldDismiss {
                            dismiss()
                        }
                    }
                )
            }
            .onChange(of: shouldDismiss) { newValue in
                if newValue {
                    // shouldDismiss가 true로 바뀌면 약간의 지연 후 화면 닫기
                    // 이렇게 하면 알림이 충분히 표시된 후 화면이 닫힘
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // 사용자 검색
    private func searchUser() {
        guard !searchCharacterName.isEmpty else { return }
        
        isSearching = true
        hasSearched = false
        characterDetails = nil // 검색 시작 시 상세 정보 초기화
        
        Task {
            do {
                let trimmedName = searchCharacterName.trimmingCharacters(in: .whitespacesAndNewlines)
                let user = try await friendsService.searchUserByCharacterName(trimmedName)
                
                // 사용자를 찾았으면 캐릭터 상세 정보도 가져오기
                if let foundUser = user {
                    isLoadingCharDetails = true
                    
                    // 캐릭터 상세 정보 비동기 로드
                    let details = await friendsService.fetchCharacterDetails(characterName: trimmedName)
                    
                    await MainActor.run {
                        self.characterDetails = details
                        self.isLoadingCharDetails = false
                    }
                }
                
                // MainActor를 사용하여 UI 업데이트를 메인 스레드에서 처리
                await MainActor.run {
                    self.searchedUser = user
                    self.isSearching = false
                    self.hasSearched = true
                    
                    // 내 캐릭터를 검색한 경우 - 약간의 지연 추가
                    if user?.id == AuthManager.shared.userId {
                        // 화면 전환이 완료된 후 알림 표시
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            self.alertTitle = "알림"
                            self.alertMessage = "자신을 친구로 추가할 수 없습니다."
                            self.showAlert = true
                        }
                    }
                }
            } catch {
                // 에러 처리
                await MainActor.run {
                    self.searchedUser = nil
                    self.characterDetails = nil
                    self.isSearching = false
                    self.hasSearched = true
                    
                    self.alertTitle = "검색 오류"
                    self.alertMessage = error.localizedDescription
                    self.showAlert = true
                }
            }
        }
    }
    
    // 친구 요청 보내기
    private func sendFriendRequest(to characterName: String) {
        isSearching = true
        
        Task {
            do {
                let success = try await friendsService.sendFriendRequestByCharacterName(characterName)
                
                await MainActor.run {
                    self.isSearching = false
                    
                    // 약간의 지연 후 알림 표시
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        if success {
                            self.alertTitle = "요청 성공"
                            self.alertMessage = "\(characterName) 캐릭터의 사용자에게 친구 요청을 보냈습니다."
                            self.shouldDismiss = true
                        } else {
                            self.alertTitle = "요청 실패"
                            self.alertMessage = "친구 요청을 보내는 중 오류가 발생했습니다."
                            self.showAlert = true
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.isSearching = false
                    
                    // 약간의 지연 후 알림 표시
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self.alertTitle = "요청 실패"
                        if let firebaseError = error as? FirebaseError {
                            switch firebaseError {
                            case .notAuthenticated:
                                self.alertMessage = "로그인이 필요합니다."
                            case .documentNotFound:
                                self.alertMessage = "해당 캐릭터를 찾을 수 없습니다."
                            case .dataError:
                                self.alertMessage = "이미 친구이거나 요청 중인 사용자입니다."
                            default:
                                self.alertMessage = "친구 요청을 보내는 중 오류가 발생했습니다."
                            }
                        } else {
                            self.alertMessage = error.localizedDescription
                        }
                        
                        self.showAlert = true
                    }
                }
            }
        }
    }
}

// 친구 검색 결과 UI 컴포넌트
struct UserSearchResultView: View {
    var user: User
    var characterName: String
    var characterDetails: CharacterModel?
    var isLoading: Bool = false
    var onSendRequest: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // 사용자 프로필 아이콘
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 60, height: 60)
                .foregroundColor(.blue)
            
            // 사용자 정보
            VStack(spacing: 8) {
                Text(user.displayName)
                    .font(.title3)
                    .fontWeight(.semibold)
                
                if let characterDetails = characterDetails {
                    // 대표 캐릭터 상세 정보가 있는 경우
                    VStack(spacing: 4) {
                        Text("캐릭터: \(characterDetails.name)")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 8) {
                            Text(characterDetails.server)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                            
                            Text(characterDetails.characterClass)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                            
                            Text("Lv. \(String(format: "%.2f", characterDetails.level))")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                } else {
                    // 대표 캐릭터 기본 정보만 있는 경우
                    Text("캐릭터: \(characterName)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if isLoading {
                        // 캐릭터 정보 로딩 중
                        ProgressView("캐릭터 정보 로딩 중...")
                            .font(.caption)
                    }
                }
            }
            
            // 요청 버튼
            Button(action: onSendRequest) {
                Text("친구 요청 보내기")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

struct AddFriendView_Previews: PreviewProvider {
    static var previews: some View {
        AddFriendView()
            .environmentObject(FriendsService.shared)
    }
}
