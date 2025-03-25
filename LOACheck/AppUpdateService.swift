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
    
    private init() {}
    
    // 앱스토어에서 최신 버전 정보 가져오기
    func checkForUpdate(appID: String = "6743695129") async -> Result<(latestVersion: String, releaseNotes: String?), Error> {
        do {
            // 앱스토어 API URL 구성 (국가 코드 추가)
            let url = URL(string: "https://itunes.apple.com/kr/lookup?id=\(appID)")!
            
            Logger.debug("앱 업데이트 확인 URL: \(url.absoluteString)")
            
            // API 요청
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                Logger.error("유효하지 않은 HTTP 응답")
                return .failure(NSError(domain: "AppUpdateService", code: 1, userInfo: [NSLocalizedDescriptionKey: "앱스토어 정보를 가져오는데 실패했습니다"]))
            }
            
            Logger.debug("앱스토어 API 응답 상태 코드: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode != 200 {
                Logger.error("앱스토어 API 오류 응답: \(httpResponse.statusCode)")
                return .failure(NSError(domain: "AppUpdateService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "앱스토어에서 응답을 받을 수 없습니다 (코드: \(httpResponse.statusCode))"]))
            }
            
            // 응답 디버깅
            if let responseString = String(data: data, encoding: .utf8) {
                Logger.debug("앱스토어 API 응답: \(responseString)")
            }
            
            // 응답 파싱
            let decoder = JSONDecoder()
            let result = try decoder.decode(AppStoreResponse.self, from: data)
            
            // 앱 정보가 있는지 확인
            guard let appInfo = result.results.first else {
                Logger.error("앱스토어 응답에서 앱 정보를 찾을 수 없음 (결과 수: \(result.results.count))")
                return .failure(NSError(domain: "AppUpdateService", code: 2, userInfo: [NSLocalizedDescriptionKey: "앱 정보를 찾을 수 없습니다"]))
            }
            
            Logger.debug("앱스토어 버전: \(appInfo.version)")
            return .success((latestVersion: appInfo.version, releaseNotes: appInfo.releaseNotes))
            
        } catch {
            Logger.error("업데이트 확인 중 오류 발생", error: error)
            return .failure(error)
        }
    }
    
    // 현재 버전과 최신 버전 비교
    func isUpdateAvailable(currentVersion: String, latestVersion: String) -> Bool {
        // 버전 형식: "1.0.0" -> [1, 0, 0]
        let currentComponents = currentVersion.split(separator: ".").compactMap { Int($0) }
        let latestComponents = latestVersion.split(separator: ".").compactMap { Int($0) }
        
        // 배열 길이 맞추기
        let maxLength = max(currentComponents.count, latestComponents.count)
        var paddedCurrent = currentComponents + Array(repeating: 0, count: maxLength - currentComponents.count)
        var paddedLatest = latestComponents + Array(repeating: 0, count: maxLength - latestComponents.count)
        
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
    
    // 현재 앱 버전 가져오기
    func getCurrentAppVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
}
