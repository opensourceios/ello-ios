//
//  ElloProvider.swift
//  Ello
//
//  Created by Sean Dougherty on 12/3/14.
//  Copyright (c) 2014 Ello. All rights reserved.
//

import Foundation
import Moya
import WebLinking

typealias ElloSuccessCompletion = (data: AnyObject, responseConfig: ResponseConfig) -> ()
typealias ElloFailureCompletion = (error: NSError, statusCode:Int?) -> ()

struct ElloProvider {

    static var errorStatusCode:ErrorStatusCode = .Status404

    enum ErrorStatusCode: Int {
        case Status401 = 401
        case Status403 = 403
        case Status404 = 404
        case Status410 = 410
        case Status420 = 420
        case Status422 = 422
        case Status500 = 500
        case Status502 = 502
        case Status503 = 503
        case StatusUnknown = 1_000_000

        var defaultData: NSData {
            return stubbedData(String(self.rawValue))
        }

        var notificationName: NSString {
            switch self {
            case .StatusUnknown:
                return "ElloProviderNotificationUnknown"
            default:
                return "ElloProviderNotification\(self.rawValue)"
            }
        }
    }

    static var errorEndpointsClosure = { (target: ElloAPI, method: Moya.Method, parameters: [String: AnyObject]) -> Endpoint<ElloAPI> in

        let sampleResponse = { () -> (EndpointSampleResponse) in
            return .Error(ElloProvider.errorStatusCode.rawValue, NSError(domain: ElloErrorDomain, code: 0, userInfo: [NSLocalizedFailureReasonErrorKey: "failure"]), ElloProvider.errorStatusCode.defaultData)
        }()

        var endpoint = Endpoint<ElloAPI>(URL: url(target), sampleResponse: sampleResponse, method: method, parameters: parameters)

        switch target {
        case .Auth, .ReAuth:
            return endpoint
        default:
            return endpoint.endpointByAddingHTTPHeaderFields(["Content-Type": "application/json", "Authorization": AuthToken().tokenWithBearer ?? "", "Accept-Language": ""])
        }
    }

    static var endpointsClosure = { (target: ElloAPI, method: Moya.Method, parameters: [String: AnyObject]) -> Endpoint<ElloAPI> in
        var endpoint = Endpoint<ElloAPI>(URL: url(target), sampleResponse: .Lazy({return .Success(200, target.sampleData, target.sampleResponse)}), method: method, parameters: parameters)
        switch target {
        case .Auth, .ReAuth:
            return endpoint
        default:
            return endpoint.endpointByAddingHTTPHeaderFields(["Authorization": AuthToken().tokenWithBearer ?? "", "Accept-Language": ""])
        }
    }

    static func DefaultProvider() -> MoyaProvider<ElloAPI> {
        return MoyaProvider(endpointsClosure: endpointsClosure, stubResponses: false)
    }

    static func StubbingProvider() -> MoyaProvider<ElloAPI> {
        return MoyaProvider(endpointsClosure: endpointsClosure, stubResponses: true)
    }

    private struct SharedProvider {
        static var instance = ElloProvider.DefaultProvider()
    }

    static var sharedProvider: MoyaProvider<ElloAPI> {
        get {
            return SharedProvider.instance
        }

        set (newSharedProvider) {
            SharedProvider.instance = newSharedProvider
        }
    }

    static func unCastableJSONAble(failure:ElloFailureCompletion?) {
        if let failure = failure {
            let elloError = NSError.networkError(nil, code: ElloErrorCode.JSONMapping)
            failure(error:elloError, statusCode:200)
        }
    }
}

// MARK: elloRequest implementation
extension MoyaProvider {

    func elloRequest(token: T, method: Moya.Method, parameters: [String: AnyObject], mappingType: MappingType, success: ElloSuccessCompletion, failure: ElloFailureCompletion?) {
        self.request(token, method: method, parameters: parameters, completion: {
            (data, statusCode, response, error) in
            self.handleRequest(token, method: method, parameters: parameters, data: data, response: response as? NSHTTPURLResponse, statusCode: statusCode, success: success, failure: failure, isRetry: false, mappingType: mappingType, error: error)
        })
    }

    func handleRequest(token: T, method: Moya.Method, parameters: [String: AnyObject], data:NSData?, response: NSHTTPURLResponse?, var statusCode:Int?, success: ElloSuccessCompletion, failure: ElloFailureCompletion?, isRetry: Bool, mappingType: MappingType, error:NSError?) {
        if data != nil && statusCode != nil {
            switch statusCode! {
            case 200...299:
                self.handleNetworkSuccess(data!, response: response, mappingType: mappingType, success: success, failure: failure)
            case 300...399:
                self.handleNetworkSuccess(data!, response: response, mappingType: mappingType, success: success, failure: failure)
            case 401:
                if !isRetry {
                    let authService = AuthService()
                    authService.reAuthenticate({
                        // now retry the previous request that generated the original 401
                        self.request(token, method: method, parameters: parameters, completion: { (data, statusCode, response, error) in
                            self.handleRequest(token, method: method, parameters: parameters, data: data, response: response as? NSHTTPURLResponse, statusCode: statusCode, success: success, failure: failure, isRetry: true, mappingType: mappingType, error: error)
                        })
                    },
                    failure: { (_,_) in
                        self.postNetworkFailureNotification(data, error: error, statusCode: statusCode)
                    })
                } else {
                    self.postNetworkFailureNotification(data, error: error, statusCode: statusCode)
                }
            case 410:
                self.postNetworkFailureNotification(data, error: error, statusCode: statusCode)
            case 422:
                self.handleNetworkFailure(failure, data: data, error: error, statusCode: statusCode)
            case 402...409:
                self.handleNetworkFailure(failure, data: data, error: error, statusCode: statusCode)
            case 400...499:
                self.handleNetworkFailure(failure, data: data, error: error, statusCode: statusCode)
            case 500...599:
                self.handleNetworkFailure(failure, data: data, error: error, statusCode: statusCode)
            default:
                self.handleNetworkFailure(failure, data: data, error: error, statusCode: statusCode)
            }
        }
        else {
            self.handleNetworkFailure(failure, data: data, error: error, statusCode: statusCode)
        }
    }

    func handleNetworkSuccess(data:NSData, response: NSHTTPURLResponse?, mappingType: MappingType, success:ElloSuccessCompletion, failure:ElloFailureCompletion?) {
        let (mappedJSON: AnyObject?, error) = mapJSON(data)

        var mappedObjects: AnyObject?
        if mappedJSON != nil && error == nil {
            if let dict = mappedJSON as? [String:AnyObject] {
                let linked = dict["linked"] as? [String:[[String:AnyObject]]]

                if linked != nil {
                    Store.parseLinked(linked!)
                }

                if let node = dict[mappingType.rawValue] as? [[String:AnyObject]] {
                    mappedObjects = mapToObjectArray(node, fromJSON: mappingType.fromJSON)
                }
                else if let node = dict[mappingType.rawValue] as? [String:AnyObject] {
                    mappedObjects = mapToObject(node, fromJSON: mappingType.fromJSON)
                }
            }

            if let mappedObjects: AnyObject = mappedObjects {
                success(data: mappedObjects, responseConfig: parseResponse(response))
            }
            else {
                failedToMapObjects(failure)
            }

        }
        else {
            failedToMapObjects(failure)
        }
    }

    func failedToMapObjects(failure:ElloFailureCompletion?) {
        let jsonMappingError = ElloNetworkError(attrs: nil, code: ElloNetworkError.CodeType.unknown, detail: "NEED DEFAULT HERE", messages: nil, status: nil, title: "Unknown Error")

        let elloError = NSError.networkError(jsonMappingError, code: ElloErrorCode.JSONMapping)
        if let failure = failure {
            failure(error: elloError, statusCode: nil)
        }
    }

    func postNetworkFailureNotification(data:NSData?, error: NSError?, statusCode: Int?) {
        let elloError = generateElloError(data, error: error, statusCode: statusCode)
        var notificationCase:ElloProvider.ErrorStatusCode
        if let statusCode = statusCode {
            if let noteCase = ElloProvider.ErrorStatusCode(rawValue: statusCode) {
                notificationCase = noteCase
            }
            else {
                notificationCase = ElloProvider.ErrorStatusCode.StatusUnknown
            }
        }
        else {
            notificationCase = ElloProvider.ErrorStatusCode.StatusUnknown
        }

        NSNotificationCenter.defaultCenter().postNotificationName(notificationCase.notificationName, object: elloError)
    }

    func handleNetworkFailure(failure:ElloFailureCompletion?, data:NSData?, error: NSError?, statusCode: Int?) {
        let elloError = generateElloError(data, error: error, statusCode: statusCode)

        if let failure = failure {
            failure(error: elloError, statusCode: statusCode)
        }
        else {
            self.postNetworkFailureNotification(data, error: error, statusCode: statusCode)
        }
    }

    func generateElloError(data:NSData?, error: NSError?, statusCode: Int?) -> NSError {
        var elloNetworkError:ElloNetworkError?

        if let data = data {
            let (mappedJSON: AnyObject?, error) = mapJSON(data)
            var mappedObjects: AnyObject?

            if mappedJSON != nil && error == nil {
                if let node = mappedJSON?[MappingType.ErrorsType.rawValue] as? [String:AnyObject] {
                    elloNetworkError = mapToObject(node, fromJSON: MappingType.ErrorType.fromJSON) as? ElloNetworkError
                }
            }
        }
        else {
            let detail = error?.localizedDescription ?? "NEED DEFAULT HERE"
            let jsonMappingError = ElloNetworkError(attrs: nil, code: ElloNetworkError.CodeType.unknown, detail: detail,messages: nil, status: nil, title: "Error")
        }

        var errorCodeType = (statusCode == nil) ? ElloErrorCode.Data : ElloErrorCode.StatusCode
        let elloError = NSError.networkError(elloNetworkError, code: errorCodeType)

        return elloError
    }

    func mapJSON(data: NSData) -> (AnyObject?, NSError?) {

        var error: NSError?
        var json: AnyObject? = NSJSONSerialization.JSONObjectWithData(data, options: nil, error: &error)

        if json == nil && error != nil {
            var userInfo: [NSObject : AnyObject]? = ["data": data]
            error = NSError(domain: ElloErrorDomain, code: ElloErrorCode.JSONMapping.rawValue, userInfo: userInfo)
        }

        return (json, error)
    }

    func mapToObjectArray(object: AnyObject?, fromJSON: FromJSONClosure) -> [JSONAble]? {

        if let dicts = object as? [[String:AnyObject]] {
            let jsonables:[JSONAble] =  dicts.map {
                let jsonable = fromJSON(data: $0)
                return jsonable
            }
            return jsonables
        }

        return nil
    }

    func mapToObject(object:AnyObject?, fromJSON: FromJSONClosure) -> JSONAble? {
        if let dict = object as? [String:AnyObject] {
            let jsonable = fromJSON(data: dict)
            return jsonable
        }
        else {
            return nil
        }
    }

    func parseResponse(response: NSHTTPURLResponse?) -> ResponseConfig {
        var config = ResponseConfig()
        config.totalPages = response?.allHeaderFields["X-Total-Pages"] as? String
        config.totalCount = response?.allHeaderFields["X-Total-Count"] as? String
        config.totalPagesRemaining = response?.allHeaderFields["X-Total-Pages-Remaining"] as? String
        if let nextLink = response?.findLink(relation: "next") {
            if let comps = NSURLComponents(string: nextLink.uri) {
                config.nextQueryItems = comps.queryItems
            }
        }
        if let prevLink = response?.findLink(relation: "prev") {
            if let comps = NSURLComponents(string: prevLink.uri) {
                config.prevQueryItems = comps.queryItems
            }
        }
        return config
    }
}
