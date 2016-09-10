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

class ViewController: UIViewController, BTLECentralManagerDelegate {
	
	var bleManager:BTLECentralManager!
	var myPeripheral:TestPeripheralClient?
	
	override func viewDidLoad() {
		super.viewDidLoad()
		bleManager = BTLECentralManager(withDelegate: self)
		bleManager.shouldRetrieveKnownPeripherals = false
		let prototype = TestPeripheralClient()
		bleManager.registerPeripheralPrototype(prototype)
	}
	
	func btleCentralManagerDidTurnOnBluetooth(manager: BTLECentralManager) {
		bleManager.startScanning([TestPeripheralClient.ScanForUUID])
	}
	
	func btleCentralManagerDidDiscoverPeripheral(manager: BTLECentralManager, peripheral: BLEPeripheral) {
		if let t = peripheral as? TestPeripheralClient {
			bleManager.connect(t)
		}
	}
	
	func btlePeripheralConnected(manager:BTLECentralManager,peripheral:BLEPeripheral) {
		print("connected")
	}
	
	func btlePeripheralDisconnected(manager: BTLECentralManager, peripheral: BLEPeripheral) {
		print("disconnected");
	}
	
	func btlePeripheralIsReady(manager: BTLECentralManager, peripheral: BLEPeripheral) {
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

