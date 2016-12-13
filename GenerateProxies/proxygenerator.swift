//
//  proxygenerator.swift
//  GenerateProxies
//
//  Created by Louis Melahn on 11/14/16.
//
//  Copyright © 2016 Louis Melahn.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of
//  this software and associated documentation files (the "Software"), to deal in the
//  Software without restriction, including without limitation the rights to use,
//  copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the
//  Software, and to permit persons to whom the Software is furnished to do so,
//  subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
//  FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
//  COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
//  AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
//  WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

import Foundation
import SystemConfiguration

fileprivate let proxiesDynamicStore = SCDynamicStoreCopyProxies(nil) as! Dictionary<String, Any>


fileprivate enum ProxyType: String {
    
    case http
    case https
    case ftp
    case socks
    case exceptionsList
    
    static var allMembers: [ProxyType] {
        
        return [ .http, .https, .ftp, .socks, .exceptionsList ]
        
    }
    
    var exportPrefix: String {
    
        switch self {
            
        case .socks:
            
            return "all"
        
        case .exceptionsList:
            
            return "no"
            
        default:
            
            return self.rawValue
            
        }
        
    }
    
    var proxyKey: String {
        
        switch self {
            
        case .http:
            
            return kSCPropNetProxiesHTTPProxy as String
            
        case .https:
            
            return kSCPropNetProxiesHTTPSProxy as String
            
        case .ftp:
            
            return kSCPropNetProxiesFTPProxy as String
            
        case .socks:
            
            return kSCPropNetProxiesSOCKSProxy as String
            
        case .exceptionsList:
            
            return kSCPropNetProxiesExceptionsList as String
            
        }
        
    }
    
    var portKey: String {
        
        switch self {
            
        case .http:
            
            return kSCPropNetProxiesHTTPPort as String
            
        case .https:
            
            return kSCPropNetProxiesHTTPSPort as String
            
        case .ftp:
            
            return kSCPropNetProxiesFTPPort as String
            
        case .socks:
            
            return kSCPropNetProxiesSOCKSPort as String
            
        default:
            
            return ""
            
        }
        
    }
    
    var enableKey: String {
        
        switch self {
            
        case .http:
            
            return kSCPropNetProxiesHTTPEnable as String
            
        case .https:
            
            return kSCPropNetProxiesHTTPSEnable as String
            
        case .ftp:
            
            return kSCPropNetProxiesFTPEnable as String
            
        case .socks:
            
            return kSCPropNetProxiesSOCKSEnable as String
           
        default:
            
            return ""
            
        }
        
    }
    
}

fileprivate extension String {
    
    var allCaps: String {
        
        var result = String()
        
        for character in self.characters {
            
            result.append(String(character).capitalized)
            
        }
        
        return result
    
    }
    
    var allCapitalizationVariants: [String] {
        
        let lowerCase = self.lowercased()
        let allCaps = self.allCaps
        let initialCap = self.capitalized
        
        return [lowerCase, allCaps, initialCap]
        
    }
    
}

fileprivate func getProxies() -> Dictionary<String, (address: String, port: Int, isEnabled: Bool)> {
    
    var result: Dictionary<String, (String, Int, Bool)> = [:]
    
    for proxyType in ProxyType.allMembers {
        
        let address = proxiesDynamicStore[proxyType.proxyKey] as? String ?? ""
        let port = proxiesDynamicStore[proxyType.portKey] as? Int ?? 0
        let enable = proxiesDynamicStore[proxyType.enableKey] as? Int ?? 0
        
        result[proxyType.rawValue] = (address, port, enable == 1 ? true : false)
        
    }
    
    return result;
    
}

fileprivate func makeEnvironmentCommand(proxyType: ProxyType,
                                        prefix: String,
                                        suffix: String,
                                        address: String,
                                        port: Int,
                                        isEnabled: Bool) -> String {
    
    switch proxyType {
    case .exceptionsList:
        
        let exceptionsList = getExceptionsList()
        
        if exceptionsList.isEmpty {
            
            return "export unset \(prefix)_\(suffix)"

        } else {
            
            return "export \(prefix)_\(suffix)=\"\(exceptionsList.joined(separator: ","))\""

        }
        
    default:
        
        if isEnabled {
            
            return "export \(prefix)_\(suffix)=\"\(address):\(port)\""
            
        } else {
            
            return "export unset \(prefix)_\(suffix)"
            
        }
        
    }
   
    
}

func makeProxyCommands() -> [String] {
    
    var result = [String]()
    
    let proxies = getProxies()
    
    for proxyType in ProxyType.allMembers {
        
        let proxy = proxies[proxyType.rawValue]!
        
        let address = proxy.address
        let port = proxy.port
        
        for typeVariant in proxyType.exportPrefix.allCapitalizationVariants {
            
            for proxyVariant in "proxy".allCapitalizationVariants {
                
                let newCommand = makeEnvironmentCommand(proxyType: proxyType,
                                                        prefix: typeVariant,
                                                        suffix: proxyVariant,
                                                        address: address,
                                                        port: port,
                                                        isEnabled: proxy.isEnabled)
                
                result.append(newCommand)
                
            }
        }
        
    }
    
    return result
    
}

func getExceptionsList() -> [String] {
    
    if let exceptionsList = proxiesDynamicStore[kSCPropNetProxiesExceptionsList as String] as? [String] {
        
        return exceptionsList
        
    } else {
        
        return [String]()
        
    }
    
}
