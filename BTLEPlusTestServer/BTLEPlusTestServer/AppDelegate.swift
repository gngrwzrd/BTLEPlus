//
//  AppDelegate.swift
//  BLEPlusTestServer
//
//  Created by Aaron Smith on 8/29/16.
//  Copyright © 2016 gngrwzrd. All rights reserved.
//

import Cocoa
import CoreBluetooth
import BTLEPlus

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
	@IBOutlet weak var window: NSWindow!
	var testPeripheral:TestPeripheralServer?
	func applicationDidFinishLaunching(aNotification: NSNotification) {
		testPeripheral = TestPeripheralServer()
	}
}
