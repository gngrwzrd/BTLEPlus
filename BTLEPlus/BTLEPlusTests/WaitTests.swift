//
//  WaitTests.swift
//  BTLEPlus
//
//  Created by Aaron Smith on 9/14/16.
//  Copyright © 2016 gngrwzrd. All rights reserved.
//

import Foundation
import XCTest
@testable import BTLEPlus

class WaitTest : BTLEPlusSerialServiceControllerBaseTests {
	
	var waitCount:UInt = 0
	var oneTurn:Bool = false
	
	override func setUp() {
		super.setUp()
		testingExpectedMessages = true
		//                   p         c    p         c    c           p     c           p     c           p
		expectedMessages = [.PeerInfo,.Ack,.TakeTurn,.Ack,.NewMessage,.Wait,.NewMessage,.Wait,.NewMessage,.Ack]
	}
	
	func serialServiceControllerCanAcceptMoreMessages(controller: BTLEPlusSerialServiceController) -> Bool {
		if controller == periphController {
			waitCount += 1
			if waitCount >= 3 {
				return true
			}
			return false
		}
		return true
	}
	
	func serialServiceControllerShouldOfferTurnToPeer(controller: BTLEPlusSerialServiceController) -> Bool {
		if controller == periphController {
			if oneTurn {
			 return false
			}
			oneTurn = true
		}
		return true
	}
	
	func testWait() {
		let s = "148E4241-8524-4813-B55F-6BBA94C4EB70"
		let d = s.dataUsingEncoding(NSUTF8StringEncoding)
		let message = BTLEPlusSerialServiceMessage(withMessageType: 0, messageId: 0, data: d!)
		centralController?.send(message!)
		centralController?.resume()
		periphController?.resume()
		while(!done){}
	}
}