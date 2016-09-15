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
	
	var expectedMessages:[BTLEPlusSerialServiceProtocolMessageType] = []
	var centralController:BTLEPlusSerialServiceController?
	var periphController:BTLEPlusSerialServiceController?
	var done:Bool = false
	
	override func setUp() {
		centralController = BTLEPlusSerialServiceController(withRunMode: .Central)
		centralController?.delegate = self
		periphController = BTLEPlusSerialServiceController(withRunMode: .Peripheral)
		periphController?.delegate = self
		periphController?.mtu = 32
		periphController?.windowSize = 64
	}
	
	func serialServiceController(controller: BTLEPlusSerialServiceController, wantsToSendData data: NSData) {
		
		let message = BTLEPlusSerialServiceProtocolMessage(withData: data)
		
		if controller == centralController {
			print(">>> centralSent: ",message?.protocolType.rawValue)
			periphController?.receive(data)
		}
		
		if controller == periphController {
			print(">>> peripheralSent: ",message?.protocolType.rawValue)
			centralController?.receive(data)
		}
	}
	
	
	
}