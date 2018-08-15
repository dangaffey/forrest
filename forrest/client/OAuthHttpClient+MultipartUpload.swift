//
//  OAuthHttpClient+Upload.swift
//  ForREST
//
//  Created by Dan Gaffey on 11/7/17.
//  Copyright © 2017 UnchartedRealms. All rights reserved.
//

import Foundation
import Alamofire

extension OAuthHttpClient {
    
    /**
     Routes an upload to the correct attempt dispatch procedure
     */
    public func addUploadToQueue<T: ResponseHandleableProtocol>(upload: MultipartUploadPrototype<T>) {
        switch upload.getType() {
            
        case .UserAuthRequired:
            attemptUserAccessUpload(upload: upload)
            break
            
        case .AppAuthRequired:
            attemptAnyAccessUpload(upload: upload)
            break
            
        case .NoAuthRequired:
            makeUpload(uploadObject: upload)
            break
        }
    }
    
    
    /**
     Attempts to execute an upload that requires a user-level access
     */
    private func attemptUserAccessUpload<T: ResponseHandleableProtocol>(upload: MultipartUploadPrototype<T>) {
        if (oauthStateProvider.userAccessIntended()) {
            makeUpload(uploadObject: upload)
            return
        }
        
        
        if (oauthStateProvider.userRefreshPossible()) {
            attemptUserAccessRefresh(upload: upload)
            return
        }
        
        upload.getResponseHandler().getFailureCallback()(ForRESTError.expiredCredentials)
    }
    
    
    /**
     Attempts to make a request preferring user-level, but trying application-level if unavailable
     */
    private func attemptAnyAccessUpload<T: ResponseHandleableProtocol>(upload: MultipartUploadPrototype<T>)
    {
        if (oauthStateProvider.userAccessIntended()) {
            attemptUserAccessUpload(upload: upload)
            return
        }
        
        attemptAppAccessUpload(upload: upload)
    }
    
    
    /**
     Attempts to execute an application level request
     */
    private func attemptAppAccessUpload<T: ResponseHandleableProtocol>(upload: MultipartUploadPrototype<T>)
    {
        if (oauthStateProvider.appAccessTokenValid()) {
            makeUpload(uploadObject: upload)
            return
        }
        
        attemptAppAuthentication(upload: upload)
    }
    
    
    
    /**
     Attempts to broker a new application access token under a request
     */
    private func attemptAppAuthentication<T: ResponseHandleableProtocol>(upload: MultipartUploadPrototype<T>)
    {
        let parser = oauthConfigProvider.getAppAuthParser()
        let persistSuccessHandler = { [weak self] (token: AccessToken) in
            do {
                try self?.oauthStateProvider.setAppAccessData(
                    token: token.getId(),
                    expiration: token.getExpiration())
                
                self?.makeUpload(uploadObject: upload)
                
            } catch (let error) {
                upload.getResponseHandler().getFailureCallback()(ForrestError(.appAuthFailed, error: error))
            }
        }
        
        let responseHandler = ResponseHandler<AccessToken>(
            parserClosure: parser.fromJson,
            successCallback: persistSuccessHandler,
            failureCallback: upload.getResponseHandler().getFailureCallback()
        )
        
        let authRequest = RequestPrototype<ResponseHandler<AccessToken>>(
            type: .NoAuthRequired,
            method: .post,
            url: oauthConfigProvider.getAppAuthEndpoint(),
            params: parser.toJson(
                clientId: oauthConfigProvider.getClientCredentials().getClientId(),
                clientSecret: oauthConfigProvider.getClientCredentials().getClientSecret()),
            parameterEncoding: JSONEncoding.default,
            responseHandler: responseHandler
        )
        
        makeRequest(requestObject: authRequest)
    }
    
    
    /**
     Attempts to refresh the access token for user-level access
     */
    private func attemptUserAccessRefresh<T: ResponseHandleableProtocol>(upload: MultipartUploadPrototype<T>)
    {
        refreshQueue.append(DispatchWorkItem { [weak self] in
            guard let `self` = self else {
                upload.getResponseHandler().getFailureCallback()(ForRESTError.refreshFailed)
                return
            }
            self.makeUpload(uploadObject: upload)
        })
        
        if (isRefreshing) {
            return
        }
        isRefreshing = true
        
        let parser = self.oauthConfigProvider.getRefreshParser()
        
        let refreshSuccessHandler = { [weak self] (response: RefreshResponse) in
            
            guard let `self` = self else {
                upload.getResponseHandler().getFailureCallback()(ForRESTError.refreshFailed)
                return
            }
            
            do {
                try self.oauthStateProvider.setUserAccessData(
                    token: response.userToken.id,
                    expiration: response.userToken.expiration)
                
                try self.oauthStateProvider.setUserRefreshData(
                    token: response.refreshToken.id,
                    expiration: response.refreshToken.expiration)
                
            } catch (let error) {
                upload.getResponseHandler().getFailureCallback()(ForrestError(.refreshFailed, error: error))
                self.refreshQueue.removeAll()
            }
            
            self.isRefreshing = false
            self.sendPendingRequests()
        }
        
        let refreshFailureHandler = { [weak self] (error: ForrestError) in
            
            guard let `self` = self else {
                upload.getResponseHandler().getFailureCallback()(ForRESTError.refreshFailed)
                return
            }
            
            upload.getResponseHandler().getFailureCallback()(error)
            self.refreshQueue.removeAll()
        }
        
        let responseHandler = ResponseHandler<RefreshResponse>(
            parserClosure: parser.fromJson,
            successCallback: refreshSuccessHandler,
            failureCallback: refreshFailureHandler
        )
        
        let refreshRequest = RequestPrototype<ResponseHandler<RefreshResponse>>(
            type: .NoAuthRequired,
            method: .post,
            url: self.oauthConfigProvider.getRefreshEndpoint(),
            params: parser.toJson(token: self.oauthStateProvider.getUserRefreshData()?.token ?? ""),
            parameterEncoding: JSONEncoding.default,
            responseHandler: responseHandler
        )
        
        self.makeRequest(requestObject: refreshRequest)
    }
    
    
    
    /**
     Executes requests through the Alamofire stack
     */
    private func makeUpload<T: ResponseHandleableProtocol>(uploadObject: MultipartUploadPrototype<T>)
    {
        var headers = HTTPHeaders()
        let requestType = uploadObject.getType()
        
        if let authorizationHeader = getAuthorizationHeader(type: requestType) {
            headers["Authorization"] = String(format: "Bearer %@", authorizationHeader)
        }
        
        alamofire.upload(
            multipartFormData: uploadObject.getData(),
            to: uploadObject.getUrl(),
            method: uploadObject.getMethod(),
            headers: headers,
            encodingCompletion: { encodingResult in
                switch encodingResult {
                    
                case .success(let upload, _, _):
                    upload.responseData(completionHandler: uploadObject.getResponseHandler().handleResponse)
    
                case .failure(let error):
                    uploadObject.getResponseHandler().getFailureCallback()(ForrestError(.parseError, error: error))
                }
            }
        )
    }
}
