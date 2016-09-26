//
//  OptionsSetTypeTests.swift
//  BTLEPlus
//
//  Created by Aaron Smith on 9/25/16.
//  Copyright © 2016 gngrwzrd. All rights reserved.
//

import XCTest
import CoreBluetooth
@testable import BTLEPlus

class OptionsSetTypeTests : XCTestCase {
	
	func testSetting() {
		var perms = CBAttributePermissions.Readable
		perms.set(.Writeable, on: true)
		assert( perms.contains(.Writeable) )
		assert( perms.contains(.Readable) )
	}
	
	func testClearing() {
		var perms = CBAttributePermissions.Readable
		perms.set(.Writeable, on: true)
		perms.set(.Writeable, on: false)
		perms.set(.Readable, on: false)
		assert( perms.contains(.Writeable) == false)
		assert( perms.contains(.Readable) == false)
	}
	
}
