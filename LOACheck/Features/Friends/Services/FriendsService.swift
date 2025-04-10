//
//  FriendsService.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 4/8/25.
//

import Foundation
import Combine
import Firebase

/// 친구 관련 기능을 관리하는 서비스 클래스
class FriendsService: ObservableObject {
    static let shared = FriendsService()
    
    // 친구 데이터
    @Published var friends: [Friend] = []
    @Published var friendRequests: [FriendRequest] = []
    @Published var friendsWithCharacters: [FriendWithCharacters] = []
    
    // 상태 변수
    @Published var isLoading: Bool = false
    @Published var error: Error?
    
    private var searchedUsers: [User] = []
    
    private init() {}
    
    // MARK: - 친구 목록 및 요청
    
    /// 친구 목록 불러오기
    func loadFriends() async {
        guard AuthManager.shared.isLoggedIn else { return }
        
        DispatchQueue.main.async {
            self.isLoading = true
            self.error = nil
        }
        
        do {
            let fetchedFriends = try await FirebaseRepository.shared.fetchFriends()
            
            DispatchQueue.main.async {
                self.friends = fetchedFriends
                self.isLoading = false
            }
        } catch {
            DispatchQueue.main.async {
                self.error = error
                self.isLoading = false
            }
        }
    }
    
    /// 친구 요청 목록 불러오기
    func loadFriendRequests() async {
        guard AuthManager.shared.isLoggedIn else { return }
        
        DispatchQueue.main.async {
            self.isLoading = true
            self.error = nil
        }
        
        do {
            let fetchedRequests = try await FirebaseRepository.shared.fetchFriendRequests()
            
            DispatchQueue.main.async {
                self.friendRequests = fetchedRequests
                self.isLoading = false
            }
        } catch {
            DispatchQueue.main.async {
                self.error = error
                self.isLoading = false
            }
        }
    }
    
    /// 친구 정보와 캐릭터 정보 함께 불러오기
    func loadFriendsWithCharacters() async {
        guard AuthManager.shared.isLoggedIn else { return }
        
        DispatchQueue.main.async {
            self.isLoading = true
            self.error = nil
        }
        
        do {
            // 친구 목록 가져오기
            let fetchedFriends = try await FirebaseRepository.shared.fetchFriends()
            
            var friendsData: [FriendWithCharacters] = []
            
            // 각 친구의 캐릭터 정보 가져오기
            for friend in fetchedFriends {
                let characters = try await FirebaseRepository.shared.fetchFriendCharacters(friendUserId: friend.userId)
                
                let friendWithChars = FriendWithCharacters(
                    friend: friend,
                    characters: characters.sorted { $0.level > $1.level } // 레벨 내림차순 정렬
                )
                
                friendsData.append(friendWithChars)
            }
            
            // 친구 이름 기준으로 정렬
            friendsData.sort { $0.friend.displayName < $1.friend.displayName }
            
            DispatchQueue.main.async {
                self.friendsWithCharacters = friendsData
                self.friends = fetchedFriends
                self.isLoading = false
            }
        } catch {
            DispatchQueue.main.async {
                self.error = error
                self.isLoading = false
            }
        }
    }
    
    // 캐릭터 이름으로 사용자 및 캐릭터 정보 검색
    func searchUserByCharacterName(_ characterName: String) async throws -> (User?, CharacterModel?) {
        guard !characterName.isEmpty, AuthManager.shared.isLoggedIn else {
            throw FirebaseError.notAuthenticated
        }
        
        // FirebaseRepository의 새 메소드 사용
        return try await FirebaseRepository.shared.searchUserAndCharacterDetails(characterName)
    }
    
    // 캐릭터 이름으로 친구 요청 보내기
    func sendFriendRequestByCharacterName(_ characterName: String) async throws -> Bool {
        guard let currentUser = AuthManager.shared.currentUser else {
            throw FirebaseError.notAuthenticated
        }
        
        // 대표 캐릭터 이름 또는 기본 표시 이름 사용
        let displayName = AuthManager.shared.representativeCharacter.isEmpty ?
                          currentUser.displayName :
                          AuthManager.shared.representativeCharacter
        
        do {
            // 캐릭터 이름으로 사용자 검색
            let result = try await searchUserByCharacterName(characterName)
            guard let targetUser = result.0 else {
                throw FirebaseError.documentNotFound
            }
            
            // 자기 자신에게 요청 금지
            guard currentUser.id != targetUser.id else {
                throw FirebaseError.dataError
            }
            
            let db = Firestore.firestore()
            let batch = db.batch()
            
            // 발신 요청 참조
            let sentRequestRef = db.collection("users")
                .document(currentUser.id)
                .collection("sentRequests")
                .document(targetUser.id)
            
            // 수신 요청 참조
            let receivedRequestRef = db.collection("users")
                .document(targetUser.id)
                .collection("friendRequests")
                .document(currentUser.id)
            
            // 요청 데이터 구성
            let requestData: [String: Any] = [
                "fromUserId": currentUser.id,
                "fromUserName": displayName,
                "toUserId": targetUser.id,
                "status": "pending",
                "timestamp": FieldValue.serverTimestamp()
            ]
            
            // 기존 요청 확인
            let sentRequestSnapshot = try await sentRequestRef.getDocument()
            let receivedRequestSnapshot = try await receivedRequestRef.getDocument()
            
            // 이미 요청이 존재하는 경우 예외 처리
            if sentRequestSnapshot.exists || receivedRequestSnapshot.exists {
                throw FirebaseError.dataError
            }
            
            // 배치에 쓰기 작업 추가
            batch.setData(requestData, forDocument: sentRequestRef)
            batch.setData(requestData, forDocument: receivedRequestRef)
            
            // 배치 커밋
            try await batch.commit()
            
            return true
        } catch {
            // 구체적인 에러 로깅
            Logger.error("친구 요청 실패", error: error)
            throw error
        }
    }
    
    // 캐릭터 이름으로 상세 정보 가져오기
    func fetchCharacterDetails(characterName: String) async -> CharacterModel? {
        do {
            guard !characterName.isEmpty, AuthManager.shared.isLoggedIn else {
                return nil
            }
            
            // 캐릭터 이름으로 사용자 및 캐릭터 정보 검색
            let result = try await searchUserByCharacterName(characterName)
            return result.1  // 직접 캐릭터 모델 반환
        } catch {
            Logger.error("캐릭터 상세 정보 가져오기 실패: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// 친구 요청 수락
    func acceptFriendRequest(from userId: String) async -> Bool {
        guard AuthManager.shared.isLoggedIn else { return false }
        
        DispatchQueue.main.async {
            self.isLoading = true
            self.error = nil
        }
        
        do {
            try await FirebaseRepository.shared.acceptFriendRequest(from: userId)
            
            // 요청 목록에서 제거
            DispatchQueue.main.async {
                self.friendRequests.removeAll { $0.fromUserId == userId }
                self.isLoading = false
            }
            
            // 친구 목록 갱신
            await loadFriends()
            
            return true
        } catch {
            DispatchQueue.main.async {
                self.error = error
                self.isLoading = false
            }
            return false
        }
    }
    
    /// 친구 요청 거절
    func rejectFriendRequest(from userId: String) async -> Bool {
        guard AuthManager.shared.isLoggedIn else { return false }
        
        DispatchQueue.main.async {
            self.isLoading = true
            self.error = nil
        }
        
        do {
            try await FirebaseRepository.shared.rejectFriendRequest(from: userId)
            
            // 요청 목록에서 제거
            DispatchQueue.main.async {
                self.friendRequests.removeAll { $0.fromUserId == userId }
                self.isLoading = false
            }
            
            return true
        } catch {
            DispatchQueue.main.async {
                self.error = error
                self.isLoading = false
            }
            return false
        }
    }
    
    /// 친구 삭제
    func removeFriend(userId: String) async -> Bool {
        guard AuthManager.shared.isLoggedIn else { return false }
        
        DispatchQueue.main.async {
            self.isLoading = true
            self.error = nil
        }
        
        do {
            try await FirebaseRepository.shared.removeFriend(userId: userId)
            
            // 친구 목록에서 제거
            DispatchQueue.main.async {
                self.friends.removeAll { $0.userId == userId }
                self.friendsWithCharacters.removeAll { $0.friend.userId == userId }
                self.isLoading = false
            }
            
            return true
        } catch {
            DispatchQueue.main.async {
                self.error = error
                self.isLoading = false
            }
            return false
        }
    }
    
    /// 특정 친구의 프로필 확장/축소 토글
    func toggleFriendExpanded(friendId: String) {
        if let index = friendsWithCharacters.firstIndex(where: { $0.friend.id == friendId }) {
            friendsWithCharacters[index].isExpanded.toggle()
        }
    }
    
    /// 오류 정보 초기화
    func clearError() {
        self.error = nil
    }
}
