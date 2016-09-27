//
//  BTLEPlusTestAdvertisementData.swift
//  BTLEPlus
//
//  Created by Aaron Smith on 8/26/16.
//  Copyright © 2016 gngrwzrd. All rights reserved.
//

import XCTest
import CoreBluetooth
@testable import BTLEPlus

class BTLEPlusTestAdvertisementData : XCTestCase {
	
	override func setUp() {
		super.setUp()
		// Put setup code here. This method is called before the invocation of each test method in the class.
	}
	
	override func tearDown() {
		// Put teardown code here. This method is called after the invocation of each test method in the class.
		super.tearDown()
	}
	
	func testLocalName1() {
		let data = [CBAdvertisementDataLocalNameKey:"testLocalName"]
		let adv = BTLEAdvertisementData(discoveredData: data)
		assert(adv.localName! == "testLocalName")
	}
	
	func testLocalName2() {
		let adv = BTLEAdvertisementData()
		adv.localName = "testLocalName"
		assert(adv.localName! == "testLocalName")
	}
	
	func testLocalName3() {
		let data:[String:AnyObject] = [:]
		let adv = BTLEAdvertisementData(discoveredData: data)
		assert(adv.localName == nil)
	}
	
	func testServiceUUIDs1() {
		let cbuuid = CBUUID(string: "180D")
		let data = [CBAdvertisementDataServiceUUIDsKey:[cbuuid]]
		let adv = BTLEAdvertisementData(discoveredData: data)
		assert(adv.serviceUUIDS!.count == 1)
	}
	
	func testServiceUUIDs2() {
		let cbuuid = CBUUID(string: "180D")
		let adv = BTLEAdvertisementData()
		adv.serviceUUIDS = [cbuuid]
		assert(adv.serviceUUIDS!.count == 1)
	}
	
	func testIsConnectable() {
		var adv = BTLEAdvertisementData()
		adv.isConnectable = NSNumber.init(bool: true)
		assert(adv.isConnectable != nil)
		assert(adv.isConnectable!.boolValue == true)
		
		let data:[String:AnyObject] = [CBAdvertisementDataIsConnectable: NSNumber.init(bool: true) ]
		adv = BTLEAdvertisementData(discoveredData: data)
		assert(adv.isConnectable != nil)
		assert(adv.isConnectable!.boolValue == true)
	}
	
	func testAdvertisementData() {
		let data = NSMutableData()
		var adv = BTLEAdvertisementData()
		adv.manufacturerData = data
		assert(adv.manufacturerData != nil)
		
		let ddata:[String:AnyObject] = [CBAdvertisementDataManufacturerDataKey:data]
		adv = BTLEAdvertisementData(discoveredData: ddata)
		assert(adv.manufacturerData != nil)
		assert(adv.manufacturerData == data)
	}
	
	func testOverflowServiceUUIDs() {
		let cbuuid = CBUUID(string: "180D")
		var adv = BTLEAdvertisementData()
		adv.overflowServiceUUIDs = [cbuuid]
		assert(adv.overflowServiceUUIDs != nil)
		
		let data:[String:AnyObject] = [CBAdvertisementDataOverflowServiceUUIDsKey:[cbuuid]]
		adv = BTLEAdvertisementData(discoveredData: data)
		assert(adv.overflowServiceUUIDs != nil)
		assert(adv.overflowServiceUUIDs![0] == cbuuid)
	}
	
}
