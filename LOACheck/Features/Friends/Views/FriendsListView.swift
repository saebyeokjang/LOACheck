//
//  FriendsListView.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 4/8/25.
//

import SwiftUI

struct FriendsListView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var friendsService = FriendsService.shared
    
    @State private var showAddFriendSheet = false
    @State private var showFriendRequests = false
    @State private var refreshTrigger = false
    @State private var showingRemoveAlert = false
    @State private var friendToRemove: Friend?
    
    var body: some View {
        NavigationStack {
            Group {
                if !authManager.isLoggedIn {
                    // 로그인하지 않은 경우
                    NotLoggedInView()
                } else if friendsService.isLoading {
                    // 로딩 중
                    ProgressView("친구 목록을 불러오는 중...")
                } else if friendsService.friendsWithCharacters.isEmpty {
                    // 친구가 없는 경우
                    EmptyFriendsView()
                } else {
                    // 친구 목록
                    FriendsScrollView(
                        friendsWithCharacters: friendsService.friendsWithCharacters,
                        onRemoveFriend: { friend in
                            friendToRemove = friend
                            showingRemoveAlert = true
                        }
                    )
                }
            }
            .navigationTitle("친구 목록")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if authManager.isLoggedIn {
                        HStack(spacing: 16) {
                            // 친구 요청 버튼 (아이콘 제거, 텍스트로 표시)
                            Button(action: {
                                showFriendRequests = true
                            }) {
                                Text("친구요청")
                                    .foregroundColor(friendsService.friendRequests.isEmpty ? .blue : .orange)
                            }
                            .badge(friendsService.friendRequests.isEmpty ? 0 : friendsService.friendRequests.count)
                            
                            // 친구 추가 버튼 (아이콘 제거, 텍스트로 표시)
                            Button(action: {
                                showAddFriendSheet = true
                            }) {
                                Text("친구추가")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddFriendSheet) {
                AddFriendView()
                    .environmentObject(friendsService)
            }
            .sheet(isPresented: $showFriendRequests) {
                FriendRequestsView()
                    .environmentObject(friendsService)
                    .onDisappear {
                        Task {
                            await refreshFriends()
                        }
                    }
            }
            .alert("친구 삭제", isPresented: $showingRemoveAlert, presenting: friendToRemove) { friend in
                Button("취소", role: .cancel) {}
                Button("삭제", role: .destructive) {
                    Task {
                        if await friendsService.removeFriend(userId: friend.userId) {
                            // 삭제 성공 - 필요한 경우 피드백 제공
                        }
                    }
                }
            } message: { friend in
                Text("\(friend.displayName)님을 친구 목록에서 삭제하시겠습니까?")
            }
            .onChange(of: authManager.isLoggedIn) { _, isLoggedIn in
                if isLoggedIn {
                    Task {
                        await refreshFriends()
                    }
                }
            }
            .onAppear {
                if authManager.isLoggedIn {
                    Task {
                        await refreshFriends()
                    }
                }
            }
        }
    }
    
    // 친구 목록 새로고침
    private func refreshFriends() async {
        await friendsService.loadFriendsWithCharacters()
        await friendsService.loadFriendRequests()
    }
}

// 친구 목록 스크롤 뷰 (분리된 컴포넌트)
struct FriendsScrollView: View {
    var friendsWithCharacters: [FriendWithCharacters]
    var onRemoveFriend: (Friend) -> Void
    
    var body: some View {
        List {
            ForEach(friendsWithCharacters) { friendWithChars in
                FriendCardView(
                    friendWithCharacters: friendWithChars,
                    onRemove: onRemoveFriend
                )
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10))
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        onRemoveFriend(friendWithChars.friend)
                    } label: {
                        Label("삭제", systemImage: "trash")
                    }
                }
            }
            .listRowBackground(Color.clear)
        }
        .listStyle(PlainListStyle())
        .refreshable {
            // 로컬 state를 사용하여 refreshable 작업을 처리할 수 없으므로
            // 여기서는 간단한 딜레이만 추가하고 상위 뷰에서 처리하도록 함
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5초 대기
        }
    }
}

// 로그인하지 않은 경우 표시할 뷰
struct NotLoggedInView: View {
    @State private var showSignIn = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundColor(.gray)
            
            Text("친구 기능을 사용하려면 로그인이 필요합니다")
                .font(.headline)
                .multilineTextAlignment(.center)
            
            Button(action: {
                showSignIn = true
            }) {
                Text("로그인하기")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
        }
        .padding()
        .sheet(isPresented: $showSignIn) {
            SignInView(isPresented: $showSignIn)
        }
    }
}

// 친구가 없는 경우 표시할 뷰
struct EmptyFriendsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.3")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundColor(.gray)
            
            Text("아직 친구가 없습니다")
                .font(.headline)
            
            Text("상단의 친구추가 버튼을 눌러 친구를 추가해보세요")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
