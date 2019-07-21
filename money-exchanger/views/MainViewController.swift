//
//  ViewController.swift
//  money-exchanger
//
//  Created by  Lực Nguyễn on 7/22/19.
//  Copyright © 2019 Nguyễn Lực. All rights reserved.
//
import UIKit
import Toaster
import DropDown
import Alamofire

class MainViewController: UIViewController, UITextFieldDelegate {
  @IBOutlet weak var _imgInputFlag: UIImageView!
  @IBOutlet weak var _btnInputFlag: UIButton!
  @IBOutlet weak var _imgOutputFlag: UIImageView!
  @IBOutlet weak var _btnOutputFlag: UIButton!
  @IBOutlet weak var _txtInputValue: UITextField!
  @IBOutlet weak var _lblInputCurrencyUnit: UILabel!
  @IBOutlet weak var _lblOutputValue: UILabel!
  @IBOutlet weak var _lblOutputCurrencyUnit: UILabel!
  @IBOutlet weak var _btnSourceFormat: UIButton!
  @IBOutlet weak var _lblUpdateStatus: UILabel!
  
  private var _inputFlagDropdown: DropDown? = nil
  private var _inputSelectedIndex: Int = -1
  private var _outputFlagDropdown: DropDown? = nil
  private var _outputSelectedIndex: Int = -1
  
  private let _numberFormatter: NumberFormatter = {
    let formattedNumber = NumberFormatter()
    formattedNumber.numberStyle = .decimal
    formattedNumber.maximumFractionDigits = 2
    return formattedNumber
  }()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    self.setupViews()
  }
  
  // Button callbacks
  @IBAction func btnSwapTouchedUpInside(_ sender: UIButton) {
    let tmpIndex = _inputSelectedIndex
    _inputSelectedIndex = _outputSelectedIndex
    _outputSelectedIndex = tmpIndex
    
    let tmpImage = _imgInputFlag.image
    _imgInputFlag.image = _imgOutputFlag.image
    _imgOutputFlag.image = tmpImage
    
    let tmpText = _lblInputCurrencyUnit.text
    _lblInputCurrencyUnit.text = _lblOutputCurrencyUnit.text
    _lblOutputCurrencyUnit.text = tmpText
    
    let outputValue = _numberFormatter.number(from: _lblOutputValue.text!)
    _txtInputValue.text = outputValue == 0 ? "" : String(describing: outputValue!)
    let inputValue = _numberFormatter.number(from: _txtInputValue.text!)
    _lblOutputValue.text = inputValue == nil ? "0" : _numberFormatter.string(from: inputValue!)
    
    self.convertAndDisplayOutputValue(fromInputText: _txtInputValue.text! as NSString)
  }
  
  @IBAction func btnSourceFormatTouchedUpInside(_ sender: UIButton) {
    let currentSourceFormat = self.currentSourceFormat()
    let nextSourceFormat: SourceFormatEnum = currentSourceFormat == .Json ? .Xml : .Json
    sender.setTitle(nextSourceFormat.rawValue, for: UIControlState.normal)
    
    self.updateCurrencyUnits()
    self.convertAndDisplayOutputValue(fromInputText: _txtInputValue.text! as NSString)
  }
  
  @IBAction func btnInputFlagTouchedUpInside(_ sender: UIButton) {
    let sourceFormat = self.currentSourceFormat()
    _inputFlagDropdown?.dataSource = ExchangeRatesManager.sharedManager.issuingCurrencyNames(forSource: sourceFormat)
    _inputFlagDropdown!.show()
  }
  
  @IBAction func btnOutputFlagTouchedUpInside(_ sender: UIButton) {
    let sourceFormat = self.currentSourceFormat()
    _outputFlagDropdown?.dataSource = ExchangeRatesManager.sharedManager.issuingCurrencyNames(forSource: sourceFormat)
    _outputFlagDropdown!.show()
  }
  
  @IBAction func btnUpdateTouchedUpInside(_ sender: UIButton) {
    self.refreshLatestRates()
  }
  
  // UITextFieldDelegate methods
  func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
    var inputText = textField.text! as NSString
    inputText = inputText.replacingCharacters(in: range, with: string) as NSString
    
    if inputText.length > 10 {
      return false
    }
    
    self.convertAndDisplayOutputValue(fromInputText: inputText)
    return true
  }
  
  // Custom functions
  func setupViews() {
    self.navigationController?.navigationBar.titleTextAttributes = [
      NSFontAttributeName : UIFont(name: "Roboto-Medium", size: 17)!
    ]
    
    let tapGesture = UITapGestureRecognizer(target: _txtInputValue, action: #selector(resignFirstResponder))
    self.view.addGestureRecognizer(tapGesture)
    _txtInputValue.attributedPlaceholder =
      NSAttributedString(string: "0", attributes: [NSForegroundColorAttributeName: _txtInputValue.textColor!])
    
    self.updateCurrencyUnits()
    self.setupDropdowns()
    
    self.refreshLatestRates()
  }
  
  func setupDropdowns() {
    DropDown.appearance().textFont = UIFont(name: "MyriadPro-Regular", size: 17)!
    
    var dropDown = DropDown()
    dropDown.anchorView = _btnInputFlag
    dropDown.direction = .bottom
    dropDown.width = 220
    dropDown.dataSource = []
    dropDown.cellConfiguration = { $1 }
    dropDown.selectionAction = { [weak self] (index, item) in
      self?._inputSelectedIndex = index
      self?.updateCurrencyUnits()
      self?.convertAndDisplayOutputValue(fromInputText: (self?._txtInputValue.text)! as NSString)
    }
    
    _inputFlagDropdown = dropDown
    
    dropDown = DropDown()
    dropDown.anchorView = _btnOutputFlag
    dropDown.direction = .bottom
    dropDown.width = 220
    dropDown.dataSource = []
    dropDown.cellConfiguration = { $1 }
    dropDown.selectionAction = { [weak self] (index, item) in
      self?._outputSelectedIndex = index
      self?.updateCurrencyUnits()
      self?.convertAndDisplayOutputValue(fromInputText: (self?._txtInputValue.text)! as NSString)
    }
    
    _outputFlagDropdown = dropDown
  }
  
  func updateCurrencyUnits() {
    let sourceFormat = self.currentSourceFormat()
    
    let ratesManager = ExchangeRatesManager.sharedManager
    
    if _inputSelectedIndex < 0 {
      _lblInputCurrencyUnit.text = ratesManager.defaultInputUnit[sourceFormat]
    } else {
      _lblInputCurrencyUnit.text = ratesManager.issuingUnits[sourceFormat]![_inputSelectedIndex]
    }
    
    if _outputSelectedIndex < 0 {
      _lblOutputCurrencyUnit.text = ratesManager.defaultOutputUnit[sourceFormat]
    } else {
      _lblOutputCurrencyUnit.text = ratesManager.issuingUnits[sourceFormat]![_outputSelectedIndex]
    }
    
    var updateStatus = "Lần cuối cập nhật ngày \(ratesManager.lastUpdateTime[sourceFormat]!)\n"
    updateStatus += "Nguồn: \(ratesManager.sourceName[sourceFormat]!)"
    _lblUpdateStatus.text = updateStatus
    
    if let image = UIImage(named: "img-currency-unit-\(_lblInputCurrencyUnit.text!)") {
      _imgInputFlag.image = image
    } else {
      _imgInputFlag.image = UIImage(named: "img-currency-unit-placeholder")
    }
    
    if let image = UIImage(named: "img-currency-unit-\(_lblOutputCurrencyUnit.text!)") {
      _imgOutputFlag.image = image
    } else {
      _imgInputFlag.image = UIImage(named: "img-currency-unit-placeholder")
    }
  }
  
  func refreshLatestRates() {
    let ratesManager = ExchangeRatesManager.sharedManager
    
    for sourceFormat in [SourceFormatEnum.Json, SourceFormatEnum.Xml] {
      UIApplication.shared.isNetworkActivityIndicatorVisible = true
      
      ratesManager.updateLatestRates(fromSource: sourceFormat) { [weak self] (errorString) in
        UIApplication.shared.isNetworkActivityIndicatorVisible = false
        
        var message = "Successfully update rates from \(sourceFormat.rawValue) source"
        if errorString != nil {
          message = "\(sourceFormat.rawValue) source error!\n\(errorString!)"
        }
        
        Toast(text: message, duration: 1).show()
        self?.updateCurrencyUnits()
      }
    }
  }
  
  func currentSourceFormat() -> SourceFormatEnum {
    return SourceFormatEnum(rawValue: _btnSourceFormat.title(for: UIControlState.normal)!)!
  }
  
  func convertAndDisplayOutputValue(fromInputText inputText: NSString) {
    let inputValue = inputText.doubleValue
    let outputValue = self.convert(inputValue: inputValue,
                                   fromCurrency: _lblInputCurrencyUnit.text!,
                                   toCurrency: _lblOutputCurrencyUnit.text!)
    _lblOutputValue.text = _numberFormatter.string(from: NSNumber(value: outputValue))
  }
  
  func convert(inputValue: Double, fromCurrency fromCurr: String, toCurrency toCurr:String) -> Double {
    let sourceFormat = self.currentSourceFormat()
    let rate = ExchangeRatesManager.sharedManager.latestRates[sourceFormat]!["\(fromCurr)-\(toCurr)"]
    return inputValue * rate!
  }
}
