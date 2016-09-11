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
	
}
