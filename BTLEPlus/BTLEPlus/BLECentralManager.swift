
import CoreBluetooth

//protocol for device manager delegate
@objc public protocol BLECentralManagerDelegate {
	
	//Bluetooth was turned on
	optional func bleCentralManagerDidTurnOnBluetooth(manager:BLECentralManager)
	
	//Bluetooth was turned off
	optional func bleCentralManagerDidTurnOffBluetooth(manager:BLECentralManager)
	
	//Bluetooth is resetting
	optional func bleCentralManagerBluetoothIsResetting(manager:BLECentralManager)
	
	//A device was discovered
	optional func bleCentralManagerDidDiscoverDevice(manager:BLECentralManager,device:BLEPeripheral)
	
	//Receive raw state updates from CBCentralManager
	optional func bleCentralManagerDidUpdateState(manager:BLECentralManager,state:CBCentralManagerState)
	
	/* device specific callbacks */
	
	//A device connected successfully
	optional func blePeripheralConnected(manager:BLECentralManager,device:BLEPeripheral)
	
	//A device failed to connect after trying BLECentralManager.MaxConnectionAttempts
	optional func blePeripheralFailedToConnect(manager:BLECentralManager,device:BLEPeripheral,error:NSError?)
	
	//A connected device is no longer connected
	optional func blePeripheralDisconnected(manager:BLECentralManager,device:BLEPeripheral)
	
	//A device failed it's setup process.
	optional func blePeripheralSetupFailed(manager:BLECentralManager,device:BLEPeripheral,error:NSError?)
	
	//A device is ready to use
	optional func blePeripheralIsReady(manager:BLECentralManager,device:BLEPeripheral)
}

///
/// The BLECentralManager discovers devices and maintains references to the devices found.
///
/// You need to subclass BLEPeripheral and register your own custom device
/// prototypes with the BLECentralManager using registerDevicePrototype. Your device
/// needs to override respondsToAdvertisementData which tells the manager
/// when to create a new device that understands what was advertised.
///
/// The default behavior is to run the manager on a dispatch queue with high
/// priority. You can customize the dispatch queue with init(withQueue:).
///
/// You can implement the delegate for notifications, as well as find devices
/// by their uuids, tags or organization name.
///
@objc public class BLECentralManager : NSObject, CBCentralManagerDelegate {
	
	/// Delegate that receives BLECentralManagerDelegate callbacks.
	public var delegate:BLECentralManagerDelegate?
	
	/// Set this to change what the user defaults key is that stores known peripherals.
	public var knownDevicesDefaultsKey = "BLEKnownPeripherals"
	
	/// Whether to include device retrieval from core bluetooth as part of the scan process.
	public var shouldRetrieveKnownDevices = true
	
	/// Options for device scanning. These are Peripheral Scanning Options
	/// from Core Bluetooth documentation.
	public var scanOptions:[String:AnyObject] = [CBCentralManagerScanOptionAllowDuplicatesKey:true]
	
	#if os(iOS)
	/// Whether to start scanning when core bluetooth restores from a background state.
	/// This only has effects for iOS.
	public var shouldScanAfterRestore = false
	#endif
	
	/// The core bluetooth central manager.
	private var btCentralManager:CBCentralManager?
	
	/// The queue to use with the manager.
	private var btCentralManagerQueue:dispatch_queue_t?
	
	/// Prototype instances - these are copied when a prototype instance can respond and communicate with a peripheral.
	private var devicePrototypes:[BLEPeripheral] = []
	
	/// All device instances known to BLECentralManager.
	private var devices:[BLEPeripheral] = []
	
	/// Advertisement data collected during scan phase. This is collected as multiple messages
	/// are sent for each device. By collecting the advertisement data this makes sure
	/// respondsToAdvertisementData can rely on it all being there at some point.
	private var collectedAdvertisementData:[NSUUID:BLEAdvertisementData] = [:]
	
	/**
	Create a default BLECentralManager using a high priority queue.
	
	- returns: BLECentralManager
	*/
	public init(withDelegate delegate:BLECentralManagerDelegate) {
		btCentralManagerQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)
		super.init()
		self.delegate = delegate
		btCentralManager = CBCentralManager(delegate:self, queue:btCentralManagerQueue)
	}
	
	/**
	Create a BLECentralManager that runs on a custom dispatch queue.
	
	- parameter queue: the dispatch_queue_t
	
	- returns: BLECentralManager
	*/
	public init(withQueue queue:dispatch_queue_t) {
		btCentralManagerQueue = queue
		super.init()
		btCentralManager = CBCentralManager(delegate:self, queue:btCentralManagerQueue)
	}
	
	//utility to copy a device prototype
	private func copyPrototype(prototype:BLEPeripheral, advertisementData:BLEAdvertisementData?, peripheral:CBPeripheral?) -> BLEPeripheral? {
		if let newDevice = prototype.copy() as? BLEPeripheral {
			newDevice.bleCentralManager = self
			newDevice.btCentralManager = btCentralManager
			newDevice.advertisementData = advertisementData
			newDevice.tag = prototype.tag
			newDevice.attempts = prototype.connectionMaxAttempts
			newDevice.connectionMaxAttempts = prototype.connectionMaxAttempts
			newDevice.connectionTimeoutLength = prototype.connectionTimeoutLength
			newDevice.subscribePhaseMaxAttempts = prototype.subscribePhaseMaxAttempts
			newDevice.subscribePhaseTimeoutLength = prototype.subscribePhaseTimeoutLength
			newDevice.discoveryPhaseMaxAttempts = prototype.discoveryPhaseMaxAttempts
			newDevice.discoveryPhaseTimeoutLength = prototype.discoveryPhaseTimeoutLength
			newDevice.additionalSetupMaxAttempts = prototype.additionalSetupMaxAttempts
			newDevice.additionalSetupTimeout = prototype.additionalSetupTimeout
			newDevice.organization = prototype.organization
			newDevice.cbPeripheral = peripheral
			newDevice.wasCopiedFromDevicePrototype(prototype)
			return newDevice
		}
		return nil
	}
	
	/**
	Find a device prototype that responds to the given advertisement data.
	
	- parameter advertisementData: BLEAdvertisementData.
	
	- returns: BLEPeripheral?
	*/
	private func findPrototype(advertisementData:BLEAdvertisementData?) -> BLEPeripheral? {
		guard let advData = advertisementData else {
			return nil
		}
		let responds = devicePrototypes.filter({$0.respondsToAdvertisementData(advData)})
		if responds.count > 0 {
			return responds[0]
		}
		return nil
	}
	
	/**
	Creates a new instance from a device prototype.
	
	- parameter peripheral:        The CBPeripheral that the prototype will manage.
	- parameter advertisementData: Advertisement data.
	
	- returns: BLEPeripheral?
	*/
	private func newPrototypeInstance(peripheral:CBPeripheral?, advertisementData:BLEAdvertisementData?) -> BLEPeripheral? {
		guard let advData = advertisementData else {
			return nil
		}
		if let prototype = findPrototype(advData) {
			if let newDevice = copyPrototype(prototype, advertisementData: advertisementData, peripheral: peripheral) {
				return newDevice
			}
		}
		return nil
	}
	
	/**
	Get a saved known peripherals advertisement data from user defaults.
	
	- parameter forUUID: The NSUUID of the peripheral.
	
	- returns: BLEAdvertisementData?
	*/
	private func knownPeripheralAdvertisementData(forUUID:NSUUID) -> BLEAdvertisementData? {
		guard let knownPeripherals = NSUserDefaults.standardUserDefaults().objectForKey(knownDevicesDefaultsKey) else {
			return nil
		}
		if let rawAdvData = knownPeripherals[ forUUID.UUIDString ] as? NSData {
			if let advData = BLEAdvertisementData.createWithData(rawAdvData) {
				return advData
			}
		}
		return nil
	}
	
	///Discover known peripherals from Core Bluetooth. This looks for currently
	///connected devices, and not connected but still known. If a device prototype
	///matches a new device is created, and either it connects, or if already connected
	///will go through the setup process starting with discovering services.
	private func discoverKnownPeripherals(services:[CBUUID]) {
		if !shouldRetrieveKnownDevices {
			return
		}
		
		//uuids to retrieve for non connected
		var uuidsToRetrieve:[NSUUID] = []
		
		//load known peripherals and grab their device uuids
		let defaults = [knownDevicesDefaultsKey:[:]]
		NSUserDefaults.standardUserDefaults().registerDefaults(defaults)
		guard let knownPeripherals = NSUserDefaults.standardUserDefaults().objectForKey(knownDevicesDefaultsKey) as? [String:NSData] else {
			return
		}
		
		//grab uuids to load
		for (uuid,_) in knownPeripherals {
			if let nsuuid = NSUUID(UUIDString: uuid) {
				uuidsToRetrieve.append(nsuuid)
			}
		}
		
		//load connected peripherals that exist with matching services.
		var peripherals = btCentralManager?.retrieveConnectedPeripheralsWithServices(services)
		if let peripherals = peripherals {
			for peripheral in peripherals {
				
				//grab identifier
				let identifier = peripheral.identifier.UUIDString
				
				//if a device already exists with this peripheral then continue
				guard deviceForPeripheral(peripheral) == nil else {
					uuidsToRetrieve = uuidsToRetrieve.filter({$0 != identifier})
					continue
				}
				
				//find advertisement data for the peripheral and see if a device prototype responds to it.
				if let rawAdvertisementData = knownPeripherals[identifier] {
					if let advertisementData = BLEAdvertisementData.createWithData(rawAdvertisementData) {
						if let newDevice = newPrototypeInstance(peripheral, advertisementData: advertisementData) {
							//remove the device from uuids to retrieve as it's already connected
							//and we don't need to look for it in the next retrieve.
							uuidsToRetrieve = uuidsToRetrieve.filter({$0 != identifier})
							
							//save device, tell it it was discovered and retrieved.
							addDevice(newDevice)
							newDevice.wasDiscovered()
							newDevice.wasRetrieved()
						}
					}
				}
			}
		}
		
		//find known, but not connected peripherals. try and reconnect if we have any matching device prototypes.
		peripherals = btCentralManager?.retrievePeripheralsWithIdentifiers(uuidsToRetrieve)
		if let peripherals = peripherals {
			for peripheral in peripherals {
				guard deviceForPeripheral(peripheral) == nil else {
					continue
				}
				for (_,data) in knownPeripherals {
					if let advertisementData = BLEAdvertisementData.createWithData(data) {
						if let newDevice = newPrototypeInstance(peripheral, advertisementData: advertisementData) {
							addDevice(newDevice)
							newDevice.wasDiscovered()
							newDevice.wasRetrieved()
						}
					}
				}
			}
		}
	}
	
	/**
	Save a known device. This should only be called after a device is ready to use.
	
	- parameter device: The device to save in NSUserDefaults.
	*/
	func saveKnownDevice(device:BLEPeripheral, advertisementData:BLEAdvertisementData?) {
		guard let advertisementData = advertisementData else {
			return
		}
		if var knownPeripherals = NSUserDefaults.standardUserDefaults().objectForKey(knownDevicesDefaultsKey) as? [String:NSData]{
			let data = NSKeyedArchiver.archivedDataWithRootObject(advertisementData)
			if let identifier = device.cbPeripheral?.identifier.UUIDString {
				knownPeripherals[identifier] = data
				NSUserDefaults.standardUserDefaults().setObject(knownPeripherals, forKey: knownDevicesDefaultsKey)
			}
		}
	}
	
	/**
	Register a device prototype. Copies of device prototypes are created when a peripheral
	is found, and a device prototype can respond to the peripheral.
	
	- parameter device: An instance of BLEPeripheral.
	*/
	public func registerDevicePrototype(device:BLEPeripheral) {
		devicePrototypes.append(device)
	}
	
	/**
	Start scanning for peripherals with services.
	
	- parameter services: Official BLE service UUIDs can be found here https://www.bluetooth.com/specifications/gatt/services.
	*/
	public func startScanning(services:[CBUUID]?) {
		collectedAdvertisementData = [:]
		if let services = services {
			if services.count < 1 {
				return
			}
			
			btCentralManager?.scanForPeripheralsWithServices(services, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
			discoverKnownPeripherals(services)
		}
	}
	
	/// Stop scanning for peripherals
	public func stopScanning() {
		collectedAdvertisementData = [:]
		btCentralManager?.stopScan()
	}
	
	/**
	Remove a device
	
	- parameter device: The device to remove
	*/
	func removeDevice(device:BLEPeripheral) {
		devices = devices.filter({$0 != device})
	}
	
	/**
	Add a device.
	
	- parameter device: The device to add
	*/
	private func addDevice(device:BLEPeripheral) {
		guard device.cbPeripheral != nil else {
			return
		}
		guard deviceForPeripheral(device.cbPeripheral!) == nil else {
			return
		}
		devices.append(device)
	}
	
	/**
	All current BLEPeripherals that BLECentralManager is managing.
	
	- returns: Array of BLEPeripheral instances.
	*/
	public func allDevices() -> [BLEPeripheral]? {
		return devices
	}
	
	/**
	Get all devices with a specific tag.
	
	- parameter tag: The device tag
	
	- returns: Array of BLEPeripheral or nil
	*/
	public func devicesForTag(tag:Int) -> [BLEPeripheral]? {
		return devices.filter({$0.tag == tag})
	}
	
	/**
	Returns a single BLEPeripheral with tag. If there are more
	than one devices with the same tag then nil is returned.
	
	- parameter tag: The device tag
	
	- returns: A BLEPeripheral or nil
	*/
	public func deviceForTag(tag:Int) -> BLEPeripheral? {
		let dvs = devices.filter({$0.tag == tag})
		if dvs.count == 1 {
			return dvs[0]
		}
		return nil
	}
	
	/**
	Returns the BLEPeripheral that is managing the CBPeripheral.
	
	- parameter peripheral: The CBPeripheral
	
	- returns: A BLEPeripheral or nil
	*/
	private func deviceForPeripheral(peripheral:CBPeripheral) -> BLEPeripheral? {
		for device in devices {
			if device.cbPeripheral?.identifier.UUIDString == peripheral.identifier.UUIDString {
				return device
			}
		}
		return nil
	}
	
	/**
	Returns a device who's peripheral UUID matches the passed uuid
	
	- parameter uuid: UUID to search for.
	*/
	public func deviceForUUID(uuid:NSUUID?) -> BLEPeripheral? {
		let dvcs = devices.filter({$0.UUID?.UUIDString == uuid?.UUIDString})
		if dvcs.count == 1 {
			return dvcs[0]
		}
		return nil
	}
	
	/**
	Returns a device who's organization matches the passed organization.
	If multiple devices are found nil is returned.
	
	- parameter organization: Organization identifier.
	
	- returns: BLEPeripheral?
	*/
	public func deviceForOrganization(organization:String?) -> BLEPeripheral? {
		let dvcs = devices.filter({$0.organization == organization})
		if dvcs.count == 1 {
			return dvcs[0]
		}
		return nil
	}
	
	/**
	Returns multiple devices for an organization.
	
	- parameter organization: Organization identifier.
	
	- returns: [BLEPeripheral]?
	*/
	public func devicesForOrganization(organization:String?) -> [BLEPeripheral]? {
		return devices.filter({$0.organization == organization})
	}
	
	/**
	Start the connection process for a device.
	
	- parameter toDevice: BLEPeripheral The device to connect to.
	*/
	public func connect(device:BLEPeripheral?) {
		device?.connect()
	}
	
	/**
	Disconnect from a device.
	
	- parameter fromDevice: The device to disconnect from.
	*/
	public func disconnect(fromDevice:BLEPeripheral?) {
		fromDevice?.disconnect()
	}
	
	/**
	Callback for CBCentralManager manager state updates.
	
	- parameter central: The central.
	*/
	public func centralManagerDidUpdateState(central: CBCentralManager) {
		switch central.state {
		case .PoweredOff:
			poweredOff()
		case .PoweredOn:
			poweredOn()
		case .Resetting:
			resetting()
		case .Unauthorized:
			break
		case .Unknown:
			break
		case .Unsupported:
			break
		}
	}
	
	/// Called when bluetooth is powered on.
	private func poweredOn() {
		delegate?.bleCentralManagerDidTurnOnBluetooth?(self)
	}
	
	/// Called when bluetooth is powered off.
	private func poweredOff() {
		delegate?.bleCentralManagerDidTurnOffBluetooth?(self)
	}
	
	/// Called with bluetooth is resetting
	private func resetting() {
		delegate?.bleCentralManagerBluetoothIsResetting?(self)
	}
	
	/// Called for decive discovery
	public func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
		
		//find any existing collected advertisement data. collected adv data is only
		//colluected during the lifetime of the scan.
		var updatedAdvData = false
		var advertisementDataObject:BLEAdvertisementData? = collectedAdvertisementData[peripheral.identifier]
		if advertisementDataObject != nil {
			updatedAdvData = true
			advertisementDataObject?.appendAdvertisementData(advertisementData)
		} else {
			advertisementDataObject = BLEAdvertisementData(data: advertisementData)
			collectedAdvertisementData[peripheral.identifier] = advertisementDataObject
		}
		
		//make sure advertisement data object exists
		guard let advObject = advertisementDataObject else {
			return
		}
		
		//if a device exists already tell it there's more advertisement data
		if let device = deviceForPeripheral(peripheral) {
			if updatedAdvData {
				device.receivedMoreAdvertisementData(advObject)
			}
			return
		}
		
		//make a new prototype instance
		if let newDevice = newPrototypeInstance(peripheral, advertisementData: advObject) {
			addDevice(newDevice)
			newDevice.RSSI = RSSI
			newDevice.wasDiscovered()
		}
	}
	
	/// Device connected
	public func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
		if let device = deviceForPeripheral(peripheral) {
			device.connected()
		}
	}
	
	/// Failed to connect to device
	public func centralManager(central: CBCentralManager, didFailToConnectPeripheral peripheral: CBPeripheral, error: NSError?) {
		guard let device = deviceForPeripheral(peripheral) else {
			return
		}
		if let error = error {
			device.btCentralManagerReceivedConnectError(error)
			return
		}
		device.btManagerReceivedFatalConnect()
	}
	
	/// Device disconnected
	public func centralManager(central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
		guard let device = deviceForPeripheral(peripheral) else {
			return
		}
		if let error = error {
			device.btCentralManagerReceivedDisconnectError(error)
			return
		}
		device.disconnected()
	}
	
	/// CoreBluetooth is restoring state.
	public func centralManager(central: CBCentralManager, willRestoreState dict: [String : AnyObject]) {
	#if os(iOS)
		
		//TODO:
		
	#endif
	}
}
