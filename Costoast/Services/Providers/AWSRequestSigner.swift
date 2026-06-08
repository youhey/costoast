//
//  AWSRequestSigner.swift
//  Costoast
//
//  Created by 池田洋平 on 2026/06/08.
//

import CryptoKit
import Foundation

enum AWSRequestSigner {
    static func sign(
        request: inout URLRequest,
        body: Data,
        accessKeyID: String,
        secretAccessKey: String,
        region: String,
        service: String,
        date: Date = Date()
    ) throws {
        let amzDate = format(date, format: "yyyyMMdd'T'HHmmss'Z'")
        let dateStamp = format(date, format: "yyyyMMdd")
        let host = request.url?.host ?? "ce.\(region).amazonaws.com"
        let payloadHash = sha256Hex(body)

        request.setValue(host, forHTTPHeaderField: "Host")
        request.setValue(amzDate, forHTTPHeaderField: "X-Amz-Date")

        let canonicalHeaders = [
            "content-type": "application/x-amz-json-1.1",
            "host": host,
            "x-amz-date": amzDate,
            "x-amz-target": "AWSInsightsIndexService.GetCostAndUsage"
        ]

        let signedHeaders = canonicalHeaders.keys.sorted().joined(separator: ";")
        let canonicalHeadersString = canonicalHeaders.keys.sorted()
            .map { "\($0):\(canonicalHeaders[$0]!)\n" }
            .joined()

        let canonicalRequest = [
            request.httpMethod ?? "POST",
            request.url?.path.isEmpty == false ? request.url!.path : "/",
            "",
            canonicalHeadersString,
            signedHeaders,
            payloadHash
        ].joined(separator: "\n")

        let credentialScope = "\(dateStamp)/\(region)/\(service)/aws4_request"
        let stringToSign = [
            "AWS4-HMAC-SHA256",
            amzDate,
            credentialScope,
            sha256Hex(Data(canonicalRequest.utf8))
        ].joined(separator: "\n")

        let signingKey = signingKey(secretAccessKey: secretAccessKey, dateStamp: dateStamp, region: region, service: service)
        let signature = hmacHex(key: signingKey, message: Data(stringToSign.utf8))
        let authorization = "AWS4-HMAC-SHA256 Credential=\(accessKeyID)/\(credentialScope), SignedHeaders=\(signedHeaders), Signature=\(signature)"
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
    }

    private static func signingKey(secretAccessKey: String, dateStamp: String, region: String, service: String) -> SymmetricKey {
        let dateKey = hmac(key: SymmetricKey(data: Data("AWS4\(secretAccessKey)".utf8)), message: Data(dateStamp.utf8))
        let dateRegionKey = hmac(key: SymmetricKey(data: dateKey), message: Data(region.utf8))
        let dateRegionServiceKey = hmac(key: SymmetricKey(data: dateRegionKey), message: Data(service.utf8))
        return SymmetricKey(data: hmac(key: SymmetricKey(data: dateRegionServiceKey), message: Data("aws4_request".utf8)))
    }

    private static func hmac(key: SymmetricKey, message: Data) -> Data {
        Data(HMAC<SHA256>.authenticationCode(for: message, using: key))
    }

    private static func hmacHex(key: SymmetricKey, message: Data) -> String {
        hmac(key: key, message: message).map { String(format: "%02x", $0) }.joined()
    }

    private static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func format(_ date: Date, format: String) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
}
