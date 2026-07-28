//
//  Untitled.swift
//  MutualInfection
//
//  Created by 1234 on 2025/10/9.
//

import Foundation
import CommonCrypto
import UIKit

class OBSUploader{
    private let accessKey: String
    private let secretKey: String
    let endpoint: String
    let bucketName: String
    
    init() {
        self.accessKey = "HPUAIA5MJT9N7DKQMEWT"
        self.secretKey = "kFAsFkI3w4bqTMl4GV7DDDYgFJn1vb19Gslh7K0c"
        self.endpoint = "obs.cn-east-3.myhuaweicloud.com"//桶域名
        self.bucketName = "feeds-sa"//桶名称
    }
    
    func uploadFile(objectKey: String, filePath: String="",uiImageData: UIImage? = nil) async throws -> Int {
        // 准备请求URL
        let urlString = "https://\(bucketName).\(endpoint)/\(objectKey)"
        guard let url = URL(string: urlString) else {
            throw OBSError.invalidURL
        }
        
        // 准备请求时间和头部
        let requestTime = Date().rfc1123String
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(requestTime, forHTTPHeaderField: "Date")
        
        // 构建规范字符串
        let contentMD5 = ""
        let contentType = ""
        let canonicalizedHeaders = ""
        let canonicalizedResource = "/\(bucketName)/\(objectKey)"
        
        let canonicalString = "PUT\n" + contentMD5 + "\n" + contentType + "\n" +
                             requestTime + "\n" + canonicalizedHeaders + canonicalizedResource
        
        print("StringToSign:[\(canonicalString)]")
        
        // 计算签名
        let signature = try calculateSignature(stringToSign: canonicalString)
        request.setValue("OBS \(accessKey):\(signature)", forHTTPHeaderField: "Authorization")
        
        if(filePath.count>0)
        {
            // 设置文件内容
            let fileURL = URL(fileURLWithPath: filePath)
            let fileData = try Data(contentsOf: fileURL)
            request.httpBody = fileData
        }else{
            if(uiImageData == nil)
            {
                return 0
            }else{
                let imageData = uiImageData?.jpegData(compressionQuality: 1)
                request.httpBody = imageData
            }
        }

        // 打印请求信息
        printRequestInfo(request: request)
        
        // 发送请求并处理响应
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OBSError.invalidResponse
        }
        
        // 打印响应信息
        printResponseInfo(response: httpResponse, data: data)
        return httpResponse.statusCode
    }
    
    private func calculateSignature(stringToSign: String) throws -> String {
        guard let secretKeyData = secretKey.data(using: .utf8),
              let stringToSignData = stringToSign.data(using: .utf8) else {
            throw OBSError.signatureCalculationFailed
        }
        
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        secretKeyData.withUnsafeBytes { secretKeyBytes in
            stringToSignData.withUnsafeBytes { stringToSignBytes in
                CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA1),
                      secretKeyBytes.baseAddress, secretKeyBytes.count,
                      stringToSignBytes.baseAddress, stringToSignBytes.count,
                      &digest)
            }
        }
        
        return Data(digest).base64EncodedString()
    }
    
    private func printRequestInfo(request: URLRequest) {
        print("Request Message:")
        print("\(request.httpMethod!) \(request.url!)")
        request.allHTTPHeaderFields?.forEach { print("\($0.key): \($0.value)") }
    }
    
    private func printResponseInfo(response: HTTPURLResponse, data: Data) {
        print("\nResponse Message:")
        print("\(response.statusCode) \(HTTPURLResponse.localizedString(forStatusCode: response.statusCode))")
        response.allHeaderFields.forEach { print("\($0.key): \($0.value)") }
        if let responseString = String(data: data, encoding: .utf8) {
            print(responseString)
        }
    }
}

enum OBSError: Error {
    case invalidURL
    case invalidResponse
    case signatureCalculationFailed
    case fileReadError
}

extension Date {
    var rfc1123String: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
        return formatter.string(from: self)
    }
}
