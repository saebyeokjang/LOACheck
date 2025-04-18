//
//  AppUpdateService.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 3/25/25.
//

import Foundation

struct AppStoreResponse: Decodable {
    let results: [AppInfo]
    
    struct AppInfo: Decodable {
        let version: String
        let releaseNotes: String?
    }
}

class AppUpdateService {
    static let shared = AppUpdateService()
    static let appID = "6743695129"
    
    private init() {}
    
    // 앱스토어에서 최신 버전 정보 가져오기
    func checkForUpdate(appID: String = AppUpdateService.appID) async -> Result<(latestVersion: String, releaseNotes: String?), Error> {
        do {
            // 앱스토어 API URL 구성 (캐시 방지 파라미터 추가)
            guard let url = URL(string: "https://itunes.apple.com/kr/lookup?id=\(appID)&t=\(Date().timeIntervalSince1970)") else {
                Logger.error("유효하지 않은 URL 형식")
                return .failure(NSError(domain: "AppUpdateService", code: 0, userInfo: [NSLocalizedDescriptionKey: "유효하지 않은 URL 형식"]))
            }
            
            // API 요청 (캐시 사용하지 않는 설정)
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                Logger.error("유효하지 않은 HTTP 응답")
                return .failure(NSError(domain: "AppUpdateService", code: 1, userInfo: [NSLocalizedDescriptionKey: "앱스토어 정보를 가져오는데 실패했습니다"]))
            }
            
            // 성공적인 응답인지 확인
            if httpResponse.statusCode != 200 {
                Logger.error("앱스토어 API 오류 응답: \(httpResponse.statusCode)")
                return .failure(NSError(domain: "AppUpdateService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "앱스토어에서 응답을 받을 수 없습니다 (코드: \(httpResponse.statusCode))"]))
            }
            
            // 응답 파싱
            let decoder = JSONDecoder()
            let result = try decoder.decode(AppStoreResponse.self, from: data)
            
            // 앱 정보가 있는지 확인
            guard let appInfo = result.results.first else {
                Logger.error("앱스토어 응답에서 앱 정보를 찾을 수 없음")
                return .failure(NSError(domain: "AppUpdateService", code: 2, userInfo: [NSLocalizedDescriptionKey: "앱 정보를 찾을 수 없습니다"]))
            }
            
            return .success((latestVersion: appInfo.version, releaseNotes: appInfo.releaseNotes))
            
        } catch {
            Logger.error("업데이트 확인 중 오류 발생", error: error)
            return .failure(error)
        }
    }
    
    // 현재 버전과 최신 버전 비교
    func isUpdateAvailable(currentVersion: String, latestVersion: String) -> Bool {
        // 버전 문자열에서 숫자만 추출하기 위한 전처리
        let normalizeCurrent = normalizeVersion(currentVersion)
        let normalizeLatest = normalizeVersion(latestVersion)
        
        // 버전 형식: "1.0.0" -> [1, 0, 0]
        let currentComponents = normalizeCurrent.split(separator: ".").compactMap { Int($0) }
        let latestComponents = normalizeLatest.split(separator: ".").compactMap { Int($0) }
        
        // 배열 길이 맞추기
        let maxLength = max(currentComponents.count, latestComponents.count)
        let paddedCurrent = currentComponents + Array(repeating: 0, count: maxLength - currentComponents.count)
        let paddedLatest = latestComponents + Array(repeating: 0, count: maxLength - latestComponents.count)
        
        // 큰 버전부터 비교
        for i in 0..<maxLength {
            if paddedLatest[i] > paddedCurrent[i] {
                return true
            } else if paddedLatest[i] < paddedCurrent[i] {
                return false
            }
        }
        
        // 모든 숫자가 같으면 업데이트 없음
        return false
    }
    
    // 버전 문자열 정규화 (베타 태그 등 제거)
    private func normalizeVersion(_ version: String) -> String {
        // '-beta', '-alpha' 등의 접미사 제거
        if let range = version.range(of: "-") {
            return String(version[..<range.lowerBound])
        }
        return version
    }
    
    // 현재 앱 버전 가져오기
    func getCurrentAppVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
}
