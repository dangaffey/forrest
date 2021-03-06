//
//  OAuthStateProviderProtocol.swift
//  ForREST
//
//  Created by Daniel Gaffey on 7/22/17.
//  Copyright © 2017 UnchartedRealms LLC. All rights reserved.
//

import Foundation


public protocol OAuthStateProviderProtocol
{
    func userAccessTokenValid() -> Bool
    
    func userRefreshTokenValid() -> Bool
    
    func appAccessTokenValid() -> Bool
    
    func setUserAccessData(token: String, expiration: String) throws
    
    func setUserRefreshData(token: String, expiration: String) throws
    
    func setAppAccessData(token: String, expiration: String) throws
    
    func getUserAccessData() -> (token: String, expiration: String)?
    
    func getUserRefreshData() -> (token: String, expiration: String)?
    
    func getAppAccessData() -> (token: String, expiration: String)?
}
