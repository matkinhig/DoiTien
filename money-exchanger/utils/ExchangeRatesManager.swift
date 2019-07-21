//
//  ExchangeRatesManager.swift
//  money-exchanger
//
//  Created by  Lực Nguyễn on 7/22/19.
//  Copyright © 2019 Nguyễn Lực. All rights reserved.
//

import Foundation
import Alamofire
import SwiftyJSON
import AEXML

enum SourceFormatEnum: String {
  case Json = "JSON", Xml = "XML"
}

typealias UpdateRatesHandler = (_ errorString: String?) -> ()

class ExchangeRatesManager: NSObject {
  // Singleton initializations
  static var sharedManager = ExchangeRatesManager()
  private override init() {}
  
  // Default values
  var defaultInputUnit: [SourceFormatEnum: String] {
    get {
      return [
        .Json: _defaultInputUnitJson,
        .Xml: _defaultInputUnitXml
      ]
    }
  }
  var defaultOutputUnit: [SourceFormatEnum: String] {
    get {
      return [
        .Json: _defaultOutputUnitJson,
        .Xml: _defaultOutputUnitXml
      ]
    }
  }
  
  var lastUpdateTime: [SourceFormatEnum: String] {
    get {
      return [
        .Json: _lastUpdateTimeJson,
        .Xml: _lastUpdateTimeXml
      ]
    }
  }
  
  var sourceName: [SourceFormatEnum: String] = [
    .Json: "Fixer.io JSON API",
    .Xml: "European Central Bank XML API"
  ]
  
  var issuingUnits: [SourceFormatEnum: [String]] {
    get {
      return [
        .Json: _issuingUnitsJson,
        .Xml: _issuingUnitsXml
      ]
    }
  }
  
  var latestRates: [SourceFormatEnum: [String: Double]] {
    get {
      return [
        .Json: _latestRatesJson,
        .Xml: _latestRatesXml
      ]
    }
  }
  
  private let _apiUrls: [SourceFormatEnum : String] = [
    .Json: "http://api.fixer.io/latest",
    .Xml: "http://www.ecb.europa.eu/stats/eurofxref/eurofxref-daily.xml"
  ]
  
  private var _defaultInputUnitJson: String = "USD"
  private var _defaultOutputUnitJson: String = "VND"
  private var _lastUpdateTimeJson: String = ""
  private var _issuingUnitsJson: [String] = ["USD", "VND"]
  private var _latestRatesJson: [String: Double] = [
    "USD-VND": 22300,
    "VND-USD": 1.0/22300
  ]
  
  private var _defaultInputUnitXml: String = "VND"
  private var _defaultOutputUnitXml: String = "USD"
  private var _lastUpdateTimeXml: String = ""
  private var _issuingUnitsXml: [String] = ["VND", "USD"]
  private var _latestRatesXml: [String: Double] = [
    "USD-VND": 22300,
    "VND-USD": 1.0/22300
  ]
  
  func updateLatestRates(fromSource source: SourceFormatEnum, completion handler: @escaping UpdateRatesHandler) {
    switch source {
    case .Json:
      self._updateRatesFromJsonSource(completion: handler)
    case .Xml:
      self._updateRatesFromXmlSource(completion: handler)
    }
  }
  
  func issuingCurrencyNames(forSource sourceFormat: SourceFormatEnum) -> [String] {
    let units = self.issuingUnits[sourceFormat]!
    return units.map { CConstants.kCurrencyNames[$0]! }
  }
  
  private func _updateRatesFromJsonSource(completion handler: @escaping UpdateRatesHandler) {
    Alamofire.request(_apiUrls[.Json]!, method: .get).responseData { [weak self] (response) in
      if response.response!.statusCode != 200 {
        handler("Data not found!")
        return
      }
      
      switch response.result {
      case .success(let jsonData):
        let jsonObj = JSON(data: jsonData)
        self?._populateJsonDataToLatestRates(json: jsonObj)
        handler(nil)
      case .failure(let error):
        handler("error: \(error)")
      }
    }
  }
  
  private func _updateRatesFromXmlSource(completion handler: @escaping UpdateRatesHandler) {
    Alamofire.request(_apiUrls[.Xml]!, method: .get).responseData { [weak self] (response) in
      if response.response!.statusCode != 200 {
        handler("Data not found!")
        return
      }
      
      switch response.result {
      case .success(let xmlData):
        do {
          let xmlDoc = try AEXMLDocument(xml: xmlData)
          self?._populateXmlDataToLatestRates(xml: xmlDoc)
          handler(nil)
        } catch (let error as NSError) {
          handler(error.userInfo["NSXMLParserErrorMessage"] as? String)
        }
      case .failure(let error):
        handler("error: \(error)")
      }
    }
  }
  
  private func _populateJsonDataToLatestRates(json: JSON) {
    _issuingUnitsJson.removeAll()
    _latestRatesJson.removeAll()
    
    _lastUpdateTimeJson = json["date"].stringValue
    
    let baseCurrency = json["base"].stringValue
    _issuingUnitsJson.append(baseCurrency)
    
    for exchangeRate in json["rates"] {
      let currency = exchangeRate.0
      let rate = exchangeRate.1.doubleValue
      
      _issuingUnitsJson.append(currency)
      _latestRatesJson["\(baseCurrency)-\(currency)"] = rate
      _latestRatesJson["\(currency)-\(baseCurrency)"] = 1.0/rate
    }
    
    _defaultInputUnitJson = baseCurrency
    _defaultOutputUnitJson = "USD"
    
    _issuingUnitsJson.sort(by: <)
    
    // Calculate another pairs of currency units
    for unit1 in _issuingUnitsJson {
      for unit2 in _issuingUnitsJson {
        // Ignore duplicate units or already existed pairs
        if _latestRatesJson["\(unit1)-\(unit2)"] != nil ||
          _latestRatesJson["\(unit2)-\(unit1)"] != nil {
          continue
        }
        
        if unit1 == unit2 {
          _latestRatesJson["\(unit1)-\(unit2)"] = 1.0
          continue
        }
        
        _latestRatesJson["\(unit1)-\(unit2)"] =
          _latestRatesJson["\(unit1)-\(baseCurrency)"]! * _latestRatesJson["\(baseCurrency)-\(unit2)"]!
        _latestRatesJson["\(unit2)-\(unit1)"] =
          _latestRatesJson["\(unit2)-\(baseCurrency)"]! * _latestRatesJson["\(baseCurrency)-\(unit1)"]!
      }
    }
  }
  
  private func _populateXmlDataToLatestRates(xml: AEXMLDocument) {
    _issuingUnitsXml.removeAll()
    _latestRatesXml.removeAll()
    
    _lastUpdateTimeXml = xml.root["Cube"]["Cube"].attributes["time"]!
    
    let baseCurrency = "EUR"
    _issuingUnitsXml.append(baseCurrency)
    
    for cube in xml.root["Cube"]["Cube"].children {
      let currency = cube.attributes["currency"]!
      let rate: Double = Double(cube.attributes["rate"]!)!
      
      _issuingUnitsXml.append(currency)
      _latestRatesXml["\(baseCurrency)-\(currency)"] = rate
      _latestRatesXml["\(currency)-\(baseCurrency)"] = 1.0/rate
    }
    
    _defaultInputUnitXml = baseCurrency
    _defaultOutputUnitXml = "USD"
    
    _issuingUnitsXml.sort(by: <)
    
    // Calculate another pairs of currency units
    for unit1 in _issuingUnitsXml {
      for unit2 in _issuingUnitsXml {
        // Ignore already existed pairs
        if _latestRatesXml["\(unit1)-\(unit2)"] != nil ||
          _latestRatesXml["\(unit2)-\(unit1)"] != nil {
          continue
        }
        
        if unit1 == unit2 {
          _latestRatesJson["\(unit1)-\(unit2)"] = 1.0
          continue
        }
        
        _latestRatesXml["\(unit1)-\(unit2)"] =
          _latestRatesXml["\(unit1)-\(baseCurrency)"]! * _latestRatesXml["\(baseCurrency)-\(unit2)"]!
        _latestRatesXml["\(unit2)-\(unit1)"] =
          _latestRatesXml["\(unit2)-\(baseCurrency)"]! * _latestRatesXml["\(baseCurrency)-\(unit1)"]!
      }
    }
  }
}
