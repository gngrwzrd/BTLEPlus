//
//  ViewController.swift
//  BLEPlusTestClientIOS
//
//  Created by Aaron Smith on 8/30/16.
//  Copyright © 2016 gngrwzrd. All rights reserved.
//

import UIKit
import CoreBluetooth
import BTLEPlusIOS

class ViewController: UIViewController, BLECentralManagerDelegate {
	
	var bleManager:BLECentralManager!
	var myPeripheral:TestPeripheralClient?
	
	override func viewDidLoad() {
		super.viewDidLoad()
		bleManager = BLECentralManager(withDelegate: self)
		bleManager.shouldRetrieveKnownDevices = false
		let prototype = TestPeripheralClient()
		bleManager.registerDevicePrototype(prototype)
	}
	
	func bleCentralManagerDidTurnOnBluetooth(manager: BLECentralManager) {
		bleManager.startScanning([TestPeripheralClient.ScanForUUID])
	}
	
	func bleCentralManagerDidDiscoverDevice(manager: BLECentralManager, device: BLEPeripheral) {
		if let t = device as? TestPeripheralClient {
			bleManager.connect(t)
		}
	}
	
	func blePeripheralConnected(manager:BLECentralManager,device:BLEPeripheral) {
		print("connected")
	}
	
	func blePeripheralDisconnected(manager: BLECentralManager, device: BLEPeripheral) {
		print("disconnected");
	}
	
	func blePeripheralIsReady(manager: BLECentralManager, device: BLEPeripheral) {
		if let p = device as? TestPeripheralClient {
			myPeripheral = p
		}
	}
	
	@IBAction func sendHelloWorld() {
		myPeripheral?.sendHelloWorld()
	}
	
	@IBAction func sendLipsum() {
		myPeripheral?.sendLipsum()
	}
	
	@IBAction func sendImage() {
		myPeripheral?.sendImage()
	}
	
	@IBAction func sendHelloWorldRequest() {
		myPeripheral?.sendHelloWorldRequest()
	}
}

