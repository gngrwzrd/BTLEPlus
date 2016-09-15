//
//  BTLEPlusSerialServiceControllerTests.swift
//  BTLEPlus
//
//  Created by Aaron Smith on 9/14/16.
//  Copyright © 2016 gngrwzrd. All rights reserved.
//

import XCTest
@testable import BTLEPlus

class BTLEPlusSerialServiceControllerBaseTests : XCTestCase, BTLEPlusSerialServiceControllerDelegate {
	
	var centralController:BTLEPlusSerialServiceController?
	var periphController:BTLEPlusSerialServiceController?
	
	override func setUp() {
		centralController = BTLEPlusSerialServiceController(withRunMode: .Central)
		centralController?.delegate = self
		periphController = BTLEPlusSerialServiceController(withRunMode: .Peripheral)
		periphController?.delegate = self
		periphController?.mtu = 32
		periphController?.windowSize = 64
	}
	
	func serialServiceController(controller: BTLEPlusSerialServiceController, wantsToSendData data: NSData) {
		if controller == centralController {
			periphController?.receive(data)
		}
		if controller == periphController {
			centralController?.receive(data)
		}
	}
	
	
	
}