//
//  FriendRequestsView.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 4/8/25.
//

import SwiftUI

struct FriendRequestsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var friendsService: FriendsService
    
    @State private var processingRequestIds: Set<String> = []
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationStack {
            List {
                if friendsService.friendRequests.isEmpty {
                    // 요청이 없을 때
                    Section {
                        HStack {
                            Spacer()
                            VStack(spacing: 12) {
                                Image(systemName: "person.crop.circle.badge.checkmark")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray)
                                
                                Text("친구 요청이 없습니다")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            Spacer()
                        }
                        .listRowBackground(Color.clear)
                    }
                } else {
                    // 친구 요청 목록
                    Section(header: Text("친구 요청")) {
                        ForEach(friendsService.friendRequests) { request in
                            FriendRequestRow(
                                request: request,
                                isProcessing: processingRequestIds.contains(request.id),
                                onAccept: {
                                    acceptRequest(request)
                                },
                                onReject: {
                                    rejectRequest(request)
                                }
                            )
                        }
                    }
                }
            }
            .navigationTitle("친구 요청")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("닫기") {
                        dismiss()
                    }
                }
            }
            .refreshable {
                await refreshRequests()
            }
            .onAppear {
                Task {
                    await refreshRequests()
                }
            }
            .alert("알림", isPresented: $showAlert) {
                Button("확인") {}
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    // 친구 요청 새로고침
    private func refreshRequests() async {
        await friendsService.loadFriendRequests()
    }
    
    // 친구 요청 수락
    private func acceptRequest(_ request: FriendRequest) {
        // 처리 중인 요청 ID 추가
        processingRequestIds.insert(request.id)
        
        Task {
            let success = await friendsService.acceptFriendRequest(from: request.fromUserId)
            
            DispatchQueue.main.async {
                // 처리 중인 요청 ID 제거
                self.processingRequestIds.remove(request.id)
                
                if success {
                    self.alertMessage = "\(request.fromUserName)님의 요청이 수락되었습니다."
                    self.showAlert = true
                } else if let error = self.friendsService.error {
                    self.alertMessage = "요청 수락 중 오류가 발생했습니다: \(error.localizedDescription)"
                    self.showAlert = true
                }
            }
        }
    }
    
    // 친구 요청 거절
    private func rejectRequest(_ request: FriendRequest) {
        // 처리 중인 요청 ID 추가
        processingRequestIds.insert(request.id)
        
        Task {
            let success = await friendsService.rejectFriendRequest(from: request.fromUserId)
            
            DispatchQueue.main.async {
                // 처리 중인 요청 ID 제거
                self.processingRequestIds.remove(request.id)
                
                if !success, let error = self.friendsService.error {
                    self.alertMessage = "요청 거절 중 오류가 발생했습니다: \(error.localizedDescription)"
                    self.showAlert = true
                }
            }
        }
    }
}

// 친구 요청 행
struct FriendRequestRow: View {
    var request: FriendRequest
    var isProcessing: Bool
    var onAccept: () -> Void
    var onReject: () -> Void
    
    var body: some View {
        HStack {
            // 사용자 정보
            VStack(alignment: .leading, spacing: 4) {
                Text(request.fromUserName)
                    .font(.headline)
                
                Text("요청일: \(request.timestamp.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 버튼 (처리 중일 때는 로딩 인디케이터)
            if isProcessing {
                ProgressView()
                    .padding(8)
            } else {
                // 수락/거절 버튼
                HStack(spacing: 12) {
                    Button(action: onReject) {
                        Image(systemName: "xmark.circle.fill")
                            .resizable()
                            .frame(width: 24, height: 24)
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.borderless)
                    
                    Button(action: onAccept) {
                        Image(systemName: "checkmark.circle.fill")
                            .resizable()
                            .frame(width: 24, height: 24)
                            .foregroundColor(.green)
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct FriendRequestsView_Previews: PreviewProvider {
    static var previews: some View {
        FriendRequestsView()
            .environmentObject(FriendsService.shared)
    }
}
