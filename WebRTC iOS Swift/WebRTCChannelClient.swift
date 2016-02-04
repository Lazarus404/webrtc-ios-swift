//
//  WebRTCChannelClient.swift
//  WebRTC iOS Swift
//
//  Created by Sushil Dahal on 2/2/16.
//  Copyright © 2016 Sushil Dahal.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import Foundation
import UIKit
import WebKit

// These methods will be called by the AppEngine chanel.  The documentation
// for these methods is found here.  (Yes, it is a JS API.)
// https://developers.google.com/appengine/docs/java/channel/javascript

protocol WebRTCMessageHandler{
    func onOpen()
    func onMessage(data: [NSObject: AnyObject])
    func onClose()
    func onError(code: Int32, description: String)
}

// Initialize with a token for an WebRTC data channel.  This will load
// channel.html and use the token to establish a data channel between the
// application and AppEngine.

class WebRTCChannelClient: NSObject, WKNavigationDelegate {
    var delegate: WebRTCMessageHandler?
    
    var webView: WKWebView = WKWebView()
    
    func initWithToken(token: String, delegate: WebRTCMessageHandler)-> WebRTCChannelClient{
        if(token.characters.count > 0){
            webView.navigationDelegate = self
            self.delegate = delegate
            if let htmlPath: String = NSBundle.mainBundle().pathForResource("channel", ofType: "html"){
                let htmlURL: NSURL = NSURL(fileURLWithPath: htmlPath)
                let path: String = String(format: "%?token=%", htmlURL.absoluteString, token)
                webView.loadRequest(NSURLRequest(URL: NSURL(string: path)!))
            }
        }
        return self
    }
    
    func webView(webView: WKWebView, decidePolicyForNavigationAction navigationAction: WKNavigationAction, decisionHandler: (WKNavigationActionPolicy) -> Void) {
        let scheme: String? = webView.URL?.scheme
        if(scheme != nil){
            if(scheme != "js-frame"){
                decisionHandler(WKNavigationActionPolicy.Allow)
            }else{
                webView.evaluateJavaScript("popQueuedMessage()", completionHandler: { (object: AnyObject?, error:NSError?) -> Void in
                    if(error == nil){
                        let queuedMessage: String = object as! String
                        let queuedMessageDict: [NSObject: AnyObject] = self.jsonStringToDictionary(queuedMessage)
                        let method: String? = queuedMessageDict["type"] as? String
                        if(method != nil){
                            let payLoad: [NSObject: AnyObject]? = queuedMessageDict["payLoad"] as? [NSObject: AnyObject]
                            if(payLoad != nil){
                                if(method == "onopen"){
                                    self.delegate?.onOpen()
                                }else if(method == "onmessage"){
                                    let data: String = payLoad!["data"] as! String
                                    let payLoadData: [NSObject: AnyObject] = self.jsonStringToDictionary(data)
                                    self.delegate?.onMessage(payLoadData)
                                }else if(method == "onclose"){
                                    self.delegate?.onClose()
                                }else if(method == "onerror"){
                                    let codeNumber: NSNumber = payLoad!["code"] as! NSNumber
                                    let code: Int32 = codeNumber.intValue
                                    let description: String = payLoad!["description"] as! String
                                    self.delegate?.onError(code, description: description)
                                }else{
                                    print("Invalid message sent from web view")
                                }
                            }
                        }
                    }else{
                        print("ERROR: \(error!.localizedDescription)")
                    }
                })
            }
            decisionHandler(WKNavigationActionPolicy.Cancel)
        }
    }
    
    func jsonStringToDictionary(str: String)->[NSObject: AnyObject]{
        let data: NSData = str.dataUsingEncoding(NSUTF8StringEncoding)!
        var dict: [NSObject: AnyObject] = [:]
        do{
            dict = try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.AllowFragments) as! [NSObject : AnyObject]
        }catch let error as NSError{
            print("ERROR: \(error.localizedDescription)")
        }
        return dict
    }
}