//
//  AlamofirePlayground.swift
//  money-exchanger
//
//  Created by  Lực Nguyễn on 7/22/19.
//  Copyright © 2019 Nguyễn Lực. All rights reserved.
//

import Foundation
import Alamofire
import SwiftyJSON
import AEXML

class AlamofirePlayground: NSObject {
  static var sharedInstance = AlamofirePlayground()
  private override init() {}
  
  func play() {
    self.manualRequest()
    self.alamofireRequest()
    self.alamofireRequest2()
    self.alamofireRequestJson()
    self.alamofireSwiftyJson()
    self.alamofireAexml()
  }
  
  func manualRequest() {
    let urlString = "http://api.fixer.io/latest"
    let urlObject = NSURL(string: urlString)
    
    let request = NSMutableURLRequest(url: urlObject! as URL)
    request.httpMethod = "GET"
    
    let task = URLSession.shared.dataTask(with: request as URLRequest) { [weak self] (data, response, error) in
      if error != nil {
        print("Error: \(error)")
        return
      }
      
      print("Response Params: \(response!)\n")
      self?._convertResponseData(data: data! as NSData)
    }
    
    task.resume()
  }
  
  func alamofireRequest()  {
    Alamofire.request("http://api.fixer.io/latest", method: .get)
      .responseData { [weak self] (response) in
        if let error = response.result.error {
          print("Error: \(error)")
          return
        }
        
        print("Response Params: \(response.response!)\n")
        
        if let data = response.data {
          self?._convertResponseData(data: data as NSData)
        }
    }
  }
  
  func alamofireRequest2() {
    Alamofire.request("http://api.fixer.io/latest", method: .get)
      .responseData { [weak self] (response) in
        print("Response Params: \(response.response!)\n")
        
        switch response.result {
        case .success(let data):
          self?._convertResponseData(data: data as NSData)
        case .failure(let error):
          print("Error: \(error)")
        }
    }
  }
  
  func alamofireRequestJson() {
    Alamofire.request("http://api.fixer.io/latest", method: .get)
      .responseJSON { (response) in
        switch response.result {
        case .success(let jsonData):
          print("Response JSON: \(jsonData)")
        case .failure(let error):
          print("Error: \(error)")
        }
    }
  }
  
  func alamofireSwiftyJson() {
    Alamofire.request("http://api.fixer.io/latest", method: .get)
      .responseData { (response) in
        switch response.result {
        case .success(let data):
          let jsonData = JSON(data: data)
          print("Response JSON: \(jsonData)")
          
          for exchangeRate: (String, JSON) in jsonData["rates"] {
            print(exchangeRate.0, exchangeRate.1.doubleValue)
          }
          
          let base = jsonData["base"]
          print(base, base.string!, base.stringValue)
          
          let bases = jsonData["bases"]
          print(base, bases.string!, "'\(bases.stringValue)'")
          
          let usd = jsonData["rates"]["USD"]
          print(usd, usd.double!, usd.doubleValue)
          
          let rates_us = jsonData["rates"]["US"]
          print(rates_us, rates_us.double!, rates_us.doubleValue)
          
          let rate_us = jsonData["rate"]["USD"]
          print(rate_us, rate_us.double!, rate_us.doubleValue)
        case .failure(let error):
          print("Error: \(error)")
        }
    }
  }
  
  func alamofireAexml() {
    Alamofire.request("http://www.ecb.europa.eu/stats/eurofxref/eurofxref-daily.xml", method: .get)
      .responseData { (response) in
        switch response.result {
        case .success(let xmlData):
          do {
            let xmlDoc = try AEXMLDocument(xml: xmlData)
            print(xmlDoc.root["Cube"]["Cube"].attributes)
            
            for cube in xmlDoc.root["Cube"]["Cube"].children {
              print(cube.attributes)
            }
          } catch (let error as NSError) {
            print("Error: \(error)")
          }
        case .failure(let error):
          print("Error: \(error)")
        }
    }
  }
  
  private func _convertResponseData(data: NSData) {
    let responseData = NSString(data: data as Data, encoding: String.Encoding.utf8.rawValue)
    print("Response Data: \(responseData!)\n")
    
    do {
      let responseJson = try JSONSerialization.jsonObject(with: data as Data, options: []) as! NSDictionary
      print("Response JSON: \(responseJson)")
    } catch (let error as NSError) {
      print("Error: \(error)")
    }
  }
}
