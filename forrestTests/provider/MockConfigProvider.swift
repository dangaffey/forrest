//
//  MockConfigProvider.swift
//  ForRESTTests
//
//  Created by Dan Gaffey on 9/21/17.
//  Copyright © 2017 UnchartedRealms. All rights reserved.
//

import Foundation

struct MockConfigProvider: OAuthConfigProviderProtocol
{
    func getUserAuthEndpoint() -> String
    {
        return "https://localhost.com/oauth/v2/token"
    }
    
    func getRefreshEndpoint() -> String
    {
        return "https://localhost.com/oauth/v2/token"
    }
    
    func getAppAuthEndpoint() -> String
    {
        return "https://localhost.com/oauth/v2/token"
    }
    
    func getClientCredentials() -> ClientCredentialsProviderProtocol
    {
        return MockClientCredentialsProvider()
    }
    
    func getRefreshParser() -> RefreshParserProtocol
    {
        return MockRefreshParser()
    }
    
    func getAppAuthParser() -> AppAuthParserProtocol
    {
        return MockAppAuthParser()
    }
    
    func getUserAuthParser() -> UserAuthParserProtocol
    {
        return MockUserAuthParser()
    }
}
