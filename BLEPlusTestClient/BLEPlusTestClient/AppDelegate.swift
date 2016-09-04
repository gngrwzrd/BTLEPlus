//
//  AppDelegate.swift
//  BLEPlusTestClient
//
//  Created by Aaron Smith on 8/30/16.
//  Copyright © 2016 Aaron Smith. All rights reserved.
//

import Cocoa
import BLEPlus
import CoreBluetooth

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, BLECentralManagerDelegate {
	
	@IBOutlet weak var window: NSWindow!
	var bleManager:BLECentralManager?
	var bleClientPeripheral:MyClientPeripheral?
	
	func applicationDidFinishLaunching(aNotification: NSNotification) {
		// Insert code here to initialize your application
		bleManager = BLECentralManager()
		let myClient = MyClientPeripheral()
		bleManager?.registerDevicePrototype(myClient)
		bleManager?.delegate = self
	}
	
	func bleCentralManagerDidTurnOnBluetooth(manager: BLECentralManager) {
		let services = [CBUUID(string:"6DC4B345-635C-4690-B51D-0D358D32D5EF")]
		bleManager?.startScanning(services)
	}
	
	func blePeripheralIsReady(manager: BLECentralManager, device: BLEPeripheral) {
		if let myClientDevice = device as? MyClientPeripheral {
			bleClientPeripheral = myClientDevice
		}
	}
	
	func bleCentralManagerDidDiscoverDevice(manager: BLECentralManager, device: BLEPeripheral) {
		if let myClientDevice = device as? MyClientPeripheral {
			bleClientPeripheral = myClientDevice
			bleManager?.connect(bleClientPeripheral)
		}
	}
}
