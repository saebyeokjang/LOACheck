//
//  FriendModels.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 4/8/25.
//

import Foundation
import FirebaseAuth

/// 사용자 정보 모델
struct User: Identifiable, Codable, Equatable {
    var id: String
    var displayName: String
    var email: String
    
    init(from firebaseUser: FirebaseAuth.User) {
        self.id = firebaseUser.uid
        self.displayName = firebaseUser.displayName ?? "사용자"
        self.email = firebaseUser.email ?? ""
    }
    
    init(id: String, displayName: String, email: String) {
        self.id = id
        self.displayName = displayName
        self.email = email
    }
}

/// 친구 정보 모델
struct Friend: Identifiable, Codable, Equatable {
    var id: String
    var userId: String
    var displayName: String
    var timestamp: Date
    
    static func == (lhs: Friend, rhs: Friend) -> Bool {
        return lhs.id == rhs.id
    }
}

/// 친구 요청 모델
struct FriendRequest: Identifiable, Codable, Equatable {
    var id: String
    var fromUserId: String
    var fromUserName: String
    var timestamp: Date
    
    static func == (lhs: FriendRequest, rhs: FriendRequest) -> Bool {
        return lhs.id == rhs.id
    }
}

/// 친구 목록에 표시되는 사용자 정보 모델 (캐릭터 포함)
struct FriendWithCharacters: Identifiable {
    var id: String { friend.id }
    var friend: Friend
    var characters: [CharacterModel]
    var isExpanded: Bool = false
    
    // 캐릭터가 많을 경우 일부만 표시하기 위한 계산 속성
    var visibleCharacters: [CharacterModel] {
        if isExpanded || characters.count <= 3 {
            return characters
        } else {
            return Array(characters.prefix(3))
        }
    }
    
    // 접었을 때 보이지 않는 추가 캐릭터 수
    var hiddenCharactersCount: Int {
        return max(0, characters.count - 3)
    }
    
    // 표시할 캐릭터가 있는지
    var hasCharacters: Bool {
        return !characters.isEmpty
    }
}
