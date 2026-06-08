//
//  BillingCredentials.swift
//  Costoast
//
//  Created by 池田洋平 on 2026/06/08.
//

import Foundation

struct BillingCredentials: Codable, Equatable {
    var apiKey: String?
    var organizationID: String?

    var awsAccessKeyID: String?
    var awsSecretAccessKey: String?
    var awsRegion: String?

    var isEmpty: Bool {
        [apiKey, organizationID, awsAccessKeyID, awsSecretAccessKey, awsRegion]
            .allSatisfy { ($0 ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
}
