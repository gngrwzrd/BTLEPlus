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

class ViewController: UIViewController, BTLEPlusCentralManagerDelegate {
	
	var bleManager:BTLEPlusCentralManager!
	var myPeripheral:TestPeripheralClient?
	
	override func viewDidLoad() {
		super.viewDidLoad()
		bleManager = BTLEPlusCentralManager(withDelegate: self)
		bleManager.shouldRetrieveKnownPeripherals = false
		let prototype = TestPeripheralClient()
		bleManager.registerPeripheralPrototype(prototype)
	}
	
	func btleCentralManagerDidTurnOnBluetooth(manager: BTLEPlusCentralManager) {
		bleManager.startScanning([TestPeripheralClient.ScanForUUID])
	}
	
	func btleCentralManagerDidDiscoverPeripheral(manager: BTLEPlusCentralManager, peripheral: BTLEPlusPeripheral) {
		if let t = peripheral as? TestPeripheralClient {
			bleManager.connect(t)
		}
	}
	
	func btlePeripheralConnected(manager:BTLEPlusCentralManager,peripheral:BTLEPlusPeripheral) {
		print("connected")
	}
	
	func btlePeripheralDisconnected(manager: BTLEPlusCentralManager, peripheral: BTLEPlusPeripheral) {
		print("disconnected");
	}
	
	func btlePeripheralIsReady(manager: BTLEPlusCentralManager, peripheral: BTLEPlusPeripheral) {
		if let p = peripheral as? TestPeripheralClient {
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

