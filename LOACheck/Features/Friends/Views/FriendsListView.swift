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
            ZStack {
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
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(friendsService.friendsWithCharacters) { friendWithChars in
                                FriendCardView(
                                    friendWithCharacters: friendWithChars,
                                    onRemove: { friend in
                                        friendToRemove = friend
                                        showingRemoveAlert = true
                                    },
                                    onToggleExpand: {
                                        friendsService.toggleFriendExpanded(friendId: friendWithChars.id)
                                    }
                                )
                            }
                        }
                        .padding()
                    }
                    .refreshable {
                        await refreshFriends()
                    }
                }
            }
            .navigationTitle("친구 목록")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if authManager.isLoggedIn {
                        Button(action: {
                            showFriendRequests = true
                        }) {
                            Label("친구 요청", systemImage: "person.crop.circle.badge.plus")
                                .foregroundColor(friendsService.friendRequests.isEmpty ? .blue : .orange)
                        }
                        .badge(friendsService.friendRequests.isEmpty ? 0 : friendsService.friendRequests.count)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if authManager.isLoggedIn {
                        Button(action: {
                            showAddFriendSheet = true
                        }) {
                            Label("친구 추가", systemImage: "person.badge.plus")
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
            
            Text("상단의 + 버튼을 눌러 친구를 추가해보세요")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            // 친구 추가 버튼 제거
        }
        .padding()
    }
}

// 친구 카드 뷰
struct FriendCardView: View {
    var friendWithCharacters: FriendWithCharacters
    var onRemove: (Friend) -> Void
    var onToggleExpand: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 친구 정보 헤더
            HStack {
                VStack(alignment: .leading) {
                    Text(friendWithCharacters.friend.displayName)
                        .font(.headline)
                    
                    Text("친구 추가 날짜: \(friendWithCharacters.friend.timestamp.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 삭제 버튼
                Button(action: {
                    onRemove(friendWithCharacters.friend)
                }) {
                    Image(systemName: "person.crop.circle.badge.xmark")
                        .foregroundColor(.red)
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)
            
            Divider()
                .padding(.horizontal)
            
            // 캐릭터 목록
            if friendWithCharacters.hasCharacters {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(friendWithCharacters.visibleCharacters) { character in
                        FriendCharacterRow(character: character)
                    }
                    
                    // 더 보기 버튼 (캐릭터가 3개 초과인 경우)
                    if friendWithCharacters.hiddenCharactersCount > 0 {
                        Button(action: onToggleExpand) {
                            HStack {
                                Text(friendWithCharacters.isExpanded ? "접기" : "\(friendWithCharacters.hiddenCharactersCount)개 더 보기")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                
                                Image(systemName: friendWithCharacters.isExpanded ? "chevron.up" : "chevron.down")
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 4)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            } else {
                Text("표시할 캐릭터가 없습니다")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

// 친구 캐릭터 행
struct FriendCharacterRow: View {
    var character: CharacterModel
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(character.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(character.server) • \(character.characterClass)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("Lv. \(String(format: "%.2f", character.level))")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.blue)
        }
        .padding(.vertical, 4)
    }
}

struct FriendsListView_Previews: PreviewProvider {
    static var previews: some View {
        FriendsListView()
            .environmentObject(AuthManager.shared)
    }
}
