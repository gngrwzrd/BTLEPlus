
import CoreBluetooth

/**
BTLEPlusCentralManagerDelegate is the protocol you implement to receive
events from a BTLEPlusCentralManager.
*/
@objc public protocol BTLEPlusCentralManagerDelegate {
	
	//MARK: - BTLEPlusCentralManager Callbacks
	
	/**
	Bluetooth was turned on.
	
	- parameter manager: BTLEPlusCentralManager
	*/
	optional func btleCentralManagerDidTurnOnBluetooth(manager:BTLEPlusCentralManager)
	
	/**
	Bluetooth was turned off.
	
	- parameter manager: BTLEPlusCentralManager
	*/
	optional func btleCentralManagerDidTurnOffBluetooth(manager:BTLEPlusCentralManager)
	
	/**
	Bluetooth is resetting.
	
	- parameter manager: BTLEPlusCentralManager
	*/
	optional func btleCentralManagerBluetoothIsResetting(manager:BTLEPlusCentralManager)
	
	/**
	A perihperal was discovered.
	
	- parameter manager: BTLEPlusCentralManager
	- parameter peripheral:  BTLEPlusPeripheral
	*/
	optional func btleCentralManagerDidDiscoverPeripheral(manager:BTLEPlusCentralManager,peripheral:BTLEPlusPeripheral)
	
	/**
	Receive raw state updates from the internal CBCentralManager.  If you want to receive callbacks
	for unknown, unsupported, or unauthorized states from CoreBluetooth use this.
	
	- parameter manager:	BTLEPlusCentralManager
	- parameter state:   CBCentralManagerState
	*/
	optional func btleCentralManagerDidUpdateState(manager:BTLEPlusCentralManager,state:CBCentralManagerState)
	
	//MARK: BTLEPlusPeripheral Callbacks
	
	/**
	A peripheral connected successfully.
	
	- parameter manager: BTLECentralManager
	- parameter peripheral:  BTLEPlusPeripheral
	*/
	optional func btlePeripheralConnected(manager:BTLEPlusCentralManager,peripheral:BTLEPlusPeripheral)
	
	/**
	A peripheral failed to connect after BTLEPlusPeripheral.maxConnectionAttempts were tried.
	
	- parameter manager: BTLECentralManager
	- parameter peripheral:  BTLEPlusPeripheral
	- parameter error:   NSError
	*/
	optional func btlePeripheralFailedToConnect(manager:BTLEPlusCentralManager,peripheral:BTLEPlusPeripheral,error:NSError?)
	
	/**
	A peripheral disconnected.
	
	- parameter manager: BTLECentralManager
	- parameter peripheral:  BTLEPlusPeripheral
	*/
	optional func btlePeripheralDisconnected(manager:BTLEPlusCentralManager,peripheral:BTLEPlusPeripheral)
	
	/**
	A peripheral failed it's setup process. See BTLEPlusPeripheral for more information about the
	setup process.
	
	- parameter manager:	BTLECentralManager
	- parameter peripheral:  BTLEPlusPeripheral
	- parameter error:   NSError
	*/
	optional func btlePeripheralSetupFailed(manager:BTLEPlusCentralManager,peripheral:BTLEPlusPeripheral,error:NSError?)
	
	/**
	A peripheral is ready to use.
	
	- parameter manager:	BTLECentralManager
	- parameter peripheral:	BTLEPlusPeripheral
	*/
	optional func btlePeripheralIsReady(manager:BTLEPlusCentralManager,peripheral:BTLEPlusPeripheral)
}

/**
The BTLECentralManager class scans for peripherals, manages discovered
peripherals, and notifies you of bluetooth events via the delegate.

Do not start scanning until you've received the delegate event
for bluetooth being turned on:

````
func btleCentralManagerDidTurnOnBluetooth(central:BTLEPlusCentralManager) {
    //safe to start scanning here.
}
````

## Registering Peripheral Prototypes

You register peripheral prototypes with this class, which extend BTLEPlusPeripheral.

When Core Bluetooth discovers a peripheral, the manager tries to find a prototype
peripheral that understands the advertised data.

````
//create a manager
let myManager = BTLECentralManager(withDelegate: self)

//create a prototype instance.
let myPeripheral = MyBTLEPeripheral()
myPeripheral.tag = 1
myPeripheral.organization = "com.example.MyBTLEPeripheral"

//Register the prototype instance.
myManager.registerPeripehralPrototype(myPeripheral)
````

You're notified via the delegate that a peripheral was discovered. The peripheral
you receive has already been verified that it understands the advertised data.

Refer to BTLEPlusPeripheral, and BTLEPlusPeripheral.respondsToAdvertisementData
for more information about responding to advertisement data.

## Restoring Core Bluetooth State on iOS

*/
@objc public class BTLEPlusCentralManager : NSObject, CBCentralManagerDelegate {
	
	//MARK: - Configuration
	
	/// Delegate that receives BTLECentralManagerDelegate callbacks.
	public var delegate:BTLEPlusCentralManagerDelegate?
	
	/// Set this to change what the user defaults key is that stores known peripherals.
	public var knownPeripheralsDefaultsKey = "BLEKnownPeripherals"
	
	/// Whether to include peripheral retrieval from core bluetooth as part of the scan process.
	public var shouldRetrieveKnownPeripherals = true
	
	/// Options for peripheral scanning. These are Peripheral Scanning Options
	/// from Core Bluetooth documentation.
	public var scanOptions:[String:AnyObject] = [CBCentralManagerScanOptionAllowDuplicatesKey:true]
	
	/// The core bluetooth central manager.
	var btCentralManager:CBCentralManager?
	
	/// The queue to use with the manager.
	var btCentralManagerQueue:dispatch_queue_t?
	
	/// Prototype instances - these are copied when a prototype instance can respond and communicate with a peripheral.
	var peripheralPrototypes:[BTLEPlusPeripheral] = []
	
	/// All peripheral instances known to BTLECentralManager.
	var peripherals:[BTLEPlusPeripheral] = []
	
	/// Advertisement data collected during scan phase. This is collected as multiple messages
	/// are sent for each peripheral. By collecting the advertisement data this makes sure
	/// respondsToAdvertisementData can rely on it all being there at some point.
	var collectedAdvertisementData:[NSUUID:BTLEAdvertisementData] = [:]
	
	/**
	Register a peripheral prototype. Copies of peripheral prototypes are
	created when a peripheral is found, and a peripheral prototype can respond
	to the peripheral.
	
	- parameter peripheral: An instance of BTLEPlusPeripheral.
	*/
	public func registerPeripheralPrototype(peripheral:BTLEPlusPeripheral) {
		peripheralPrototypes.append(peripheral)
	}
	
	//MARK: - Initializers
	
	/**
	Create a default BTLECentralManager using a high priority queue.
	
	- returns: BTLECentralManager
	*/
	public init(withDelegate delegate:BTLEPlusCentralManagerDelegate) {
		btCentralManagerQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)
		super.init()
		self.delegate = delegate
		btCentralManager = CBCentralManager(delegate:self, queue:btCentralManagerQueue)
	}
	
	/**
	Create a BTLECentralManager that runs on a custom dispatch queue.
	
	- parameter queue: the dispatch_queue_t
	
	- returns: BTLECentralManager
	*/
	public init(withDelegate delegate:BTLEPlusCentralManagerDelegate, queue:dispatch_queue_t) {
		btCentralManagerQueue = queue
		super.init()
		self.delegate = delegate
		btCentralManager = CBCentralManager(delegate:self, queue:btCentralManagerQueue)
	}
	
	//utility to copy a peripheral prototype
	func copyPrototype(prototype:BTLEPlusPeripheral, advertisementData:BTLEAdvertisementData?, peripheral:CBPeripheral?) -> BTLEPlusPeripheral? {
		if let newDevice = prototype.copy() as? BTLEPlusPeripheral {
			newDevice.btleCentralManager = self
			newDevice.btCentralManager = btCentralManager
			newDevice.advertisementData = advertisementData
			newDevice.tag = prototype.tag
			newDevice.attempts = prototype.maxAttempts
			newDevice.maxAttempts = prototype.maxAttempts
			newDevice.attemptTimeoutLength = prototype.attemptTimeoutLength
			newDevice.organization = prototype.organization
			newDevice.cbPeripheral = peripheral
			return newDevice
		}
		return nil
	}
	
	/**
	Find a peripheral prototype that responds to the given advertisement data.
	
	- parameter advertisementData: BTLEAdvertisementData.
	
	- returns: BTLEPlusPeripheral?
	*/
	func findPrototype(advertisementData:BTLEAdvertisementData?) -> BTLEPlusPeripheral? {
		guard let advData = advertisementData else {
			return nil
		}
		let responds = peripheralPrototypes.filter({$0.respondsToAdvertisementData(advData)})
		if responds.count > 0 {
			return responds[0]
		}
		return nil
	}
	
	/**
	Creates a new instance from a peripheral prototype.
	
	- parameter peripheral:        The CBPeripheral that the prototype will manage.
	- parameter advertisementData: Advertisement data.
	
	- returns: BTLEPlusPeripheral?
	*/
	func newPrototypeInstance(peripheral:CBPeripheral, advertisementData:BTLEAdvertisementData?) -> BTLEPlusPeripheral? {
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
	
	- returns: BTLEAdvertisementData?
	*/
	func knownPeripheralAdvertisementData(forUUID:NSUUID) -> BTLEAdvertisementData? {
		guard let knownPeripherals = NSUserDefaults.standardUserDefaults().objectForKey(knownPeripheralsDefaultsKey) else {
			return nil
		}
		if let rawAdvData = knownPeripherals[ forUUID.UUIDString ] as? NSData {
			if let advData = BTLEAdvertisementData.createWithData(rawAdvData) {
				return advData
			}
		}
		return nil
	}
	
	///Discover known peripherals from Core Bluetooth. This looks for currently
	///connected peripherals, and not connected but still known. If a peripheral prototype
	///matches a new peripheral is created, and either it connects, or if already connected
	///will go through the setup process starting with discovering services.
	func discoverKnownPeripherals(services:[CBUUID]) {
		if !shouldRetrieveKnownPeripherals {
			return
		}
		
		//uuids to retrieve for non connected
		var uuidsToRetrieve:[NSUUID] = []
		
		//load known peripherals and grab their peripheral uuids
		let defaults = [knownPeripheralsDefaultsKey:[:]]
		NSUserDefaults.standardUserDefaults().registerDefaults(defaults)
		guard let knownPeripherals = NSUserDefaults.standardUserDefaults().objectForKey(knownPeripheralsDefaultsKey) as? [String:NSData] else {
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
				
				//if a peripheral already exists with this peripheral then continue
				guard peripheralForPeripheral(peripheral) == nil else {
					uuidsToRetrieve = uuidsToRetrieve.filter({$0 != identifier})
					continue
				}
				
				//find advertisement data for the peripheral and see if a peripheral prototype responds to it.
				if let rawAdvertisementData = knownPeripherals[identifier] {
					if let advertisementData = BTLEAdvertisementData.createWithData(rawAdvertisementData) {
						if let newDevice = newPrototypeInstance(peripheral, advertisementData: advertisementData) {
							//remove the peripheral from uuids to retrieve as it's already connected
							//and we don't need to look for it in the next retrieve.
							uuidsToRetrieve = uuidsToRetrieve.filter({$0 != identifier})
							
							//save peripheral, tell it it was discovered and retrieved.
							addPeripheral(newDevice)
							newDevice.wasDiscovered()
							newDevice.wasRetrieved()
						}
					}
				}
			}
		}
		
		//find known, but not connected peripherals. try and reconnect if we have any matching peripheral prototypes.
		peripherals = btCentralManager?.retrievePeripheralsWithIdentifiers(uuidsToRetrieve)
		if let peripherals = peripherals {
			for peripheral in peripherals {
				guard peripheralForPeripheral(peripheral) == nil else {
					continue
				}
				for (_,data) in knownPeripherals {
					if let advertisementData = BTLEAdvertisementData.createWithData(data) {
						if let newDevice = newPrototypeInstance(peripheral, advertisementData: advertisementData) {
							addPeripheral(newDevice)
							newDevice.wasDiscovered()
							newDevice.wasRetrieved()
						}
					}
				}
			}
		}
	}
	
	/**
	Save a known peripheral. This should only be called after a peripheral is ready to use.
	
	- parameter peripheral: The peripheral to save in NSUserDefaults.
	*/
	func saveKnownPeripheral(peripheral:BTLEPlusPeripheral, advertisementData:BTLEAdvertisementData?) {
		guard let advertisementData = advertisementData else {
			return
		}
		if var knownPeripherals = NSUserDefaults.standardUserDefaults().objectForKey(knownPeripheralsDefaultsKey) as? [String:NSData] {
			let data = NSKeyedArchiver.archivedDataWithRootObject(advertisementData)
			if let identifier = peripheral.cbPeripheral?.identifier.UUIDString {
				knownPeripherals[identifier] = data
				NSUserDefaults.standardUserDefaults().setObject(knownPeripherals, forKey: knownPeripheralsDefaultsKey)
			}
		}
	}
	
	//MARK: - Peripheral Scanning
	
	/**
	Start scanning for peripherals with services.
	
	- parameter services: Official BLE service UUIDs can be found here https://www.bluetooth.com/specifications/gatt/services.
	*/
	public func startScanning(services:[CBUUID]) {
		collectedAdvertisementData = [:]
		if services.count < 1 {
			return
		}
		btCentralManager?.scanForPeripheralsWithServices(services, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
		discoverKnownPeripherals(services)
	}
	
	/// Stop scanning for peripherals
	public func stopScanning() {
		collectedAdvertisementData = [:]
		btCentralManager?.stopScan()
	}
	
	/**
	Remove a peripheral
	
	- parameter peripheral: The peripheral to remove
	*/
	func removePeripheral(peripheral:BTLEPlusPeripheral) {
		peripherals = peripherals.filter({$0 != peripheral})
	}
	
	/**
	Add a peripheral.
	
	- parameter peripheral: The peripheral to add
	*/
	func addPeripheral(peripheral:BTLEPlusPeripheral) {
		guard peripheral.cbPeripheral != nil else {
			return
		}
		guard peripheralForPeripheral(peripheral.cbPeripheral!) == nil else {
			return
		}
		peripherals.append(peripheral)
	}
	
	//MARK: - Finding Discovered Peripherals
	
	/**
	All current BTLEPlusPeripherals that BTLECentralManager is managing.
	
	- returns: Array of BTLEPlusPeripheral instances.
	*/
	public func allPeripherals() -> [BTLEPlusPeripheral] {
		return peripherals
	}
	
	/**
	Get all peripherals with a specific tag.
	
	- parameter tag: The peripheral tag
	
	- returns: Array of BTLEPlusPeripheral or nil
	*/
	public func peripheralsForTag(tag:Int) -> [BTLEPlusPeripheral] {
		return peripherals.filter({$0.tag == tag})
	}
	
	/**
	Returns a single BTLEPlusPeripheral with tag. If there are more
	than one peripherals with the same tag then nil is returned.
	
	- parameter tag: The peripheral tag
	
	- returns: A BTLEPlusPeripheral or nil
	*/
	public func peripheralForTag(tag:Int) -> BTLEPlusPeripheral? {
		let dvs = peripherals.filter({$0.tag == tag})
		if dvs.count == 1 {
			return dvs[0]
		}
		return nil
	}
	
	/**
	Returns the BTLEPlusPeripheral that is managing the CBPeripheral.
	
	- parameter peripheral: The CBPeripheral
	
	- returns: A BTLEPlusPeripheral or nil
	*/
	func peripheralForPeripheral(peripheral:CBPeripheral) -> BTLEPlusPeripheral? {
		for _peripheral in peripherals {
			if _peripheral.cbPeripheral?.identifier.UUIDString == peripheral.identifier.UUIDString {
				return _peripheral
			}
		}
		return nil
	}
	
	/**
	Returns a peripheral who's peripheral UUID matches the passed uuid
	
	- parameter uuid: UUID to search for.
	*/
	public func peripheralForUUID(uuid:NSUUID?) -> BTLEPlusPeripheral? {
		let dvcs = peripherals.filter({$0.UUID?.UUIDString == uuid?.UUIDString})
		if dvcs.count == 1 {
			return dvcs[0]
		}
		return nil
	}
	
	/**
	Returns a peripheral who's organization matches the passed organization.
	If multiple peripherals are found nil is returned.
	
	- parameter organization: Organization identifier.
	
	- returns: BTLEPlusPeripheral?
	*/
	public func peripheralForOrganization(organization:String?) -> BTLEPlusPeripheral? {
		let dvcs = peripherals.filter({$0.organization == organization})
		if dvcs.count == 1 {
			return dvcs[0]
		}
		return nil
	}
	
	/**
	Returns multiple peripherals for an organization.
	
	- parameter organization: Organization identifier.
	
	- returns: [BTLEPlusPeripheral]?
	*/
	public func peripheralsForOrganization(organization:String?) -> [BTLEPlusPeripheral] {
		return peripherals.filter({$0.organization == organization})
	}
	
	//MARK: - Connectivity
	
	/**
	Start the connection process for a peripheral.
	
	- parameter peripheral: BTLEPlusPeripheral The peripheral to connect to.
	*/
	public func connect(peripheral:BTLEPlusPeripheral) {
		peripheral.connect()
	}
	
	/**
	Disconnect from a peripheral.
	
	- parameter peripheraal: The peripheral to disconnect from.
	*/
	public func disconnect(peripheral:BTLEPlusPeripheral) {
		peripheral.disconnect()
	}
	
	//MARK: - CBCentralManagerDelegate
	
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
	func poweredOn() {
		delegate?.btleCentralManagerDidTurnOnBluetooth?(self)
	}
	
	/// Called when bluetooth is powered off.
	func poweredOff() {
		delegate?.btleCentralManagerDidTurnOffBluetooth?(self)
	}
	
	/// Called when bluetooth is resetting
	func resetting() {
		delegate?.btleCentralManagerBluetoothIsResetting?(self)
	}
	
	/// Called for decive discovery
	public func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
		
		//find any existing collected advertisement data. collected adv data is only
		//collected during the lifetime of the scan.
		var updatedAdvData = false
		var advertisementDataObject:BTLEAdvertisementData? = collectedAdvertisementData[peripheral.identifier]
		if advertisementDataObject != nil {
			updatedAdvData = true
			advertisementDataObject?.appendAdvertisementData(advertisementData)
		} else {
			advertisementDataObject = BTLEAdvertisementData(discoveredData: advertisementData)
			collectedAdvertisementData[peripheral.identifier] = advertisementDataObject
		}
		
		//make sure advertisement data object exists
		guard let advObject = advertisementDataObject else {
			return
		}
		
		//if a peripheral exists already tell it there's more advertisement data
		if let _peripheral = peripheralForPeripheral(peripheral) {
			if updatedAdvData {
				_peripheral.receivedMoreAdvertisementData(advObject)
			}
			return
		}
		
		//make a new prototype instance
		if let newDevice = newPrototypeInstance(peripheral, advertisementData: advObject) {
			addPeripheral(newDevice)
			newDevice.RSSI = RSSI
			newDevice.wasDiscovered()
		}
	}
	
	/// Device connected
	public func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
		if let _peripheral = peripheralForPeripheral(peripheral) {
			_peripheral.onConnected()
		}
	}
	
	/// Failed to connect to peripheral
	public func centralManager(central: CBCentralManager, didFailToConnectPeripheral peripheral: CBPeripheral, error: NSError?) {
		guard let _peripheral = peripheralForPeripheral(peripheral) else {
			return
		}
		if let error = error {
			_peripheral.btCentralManagerReceivedConnectError(error)
			return
		}
		_peripheral.btManagerReceivedFatalConnect()
	}
	
	/// Peripheral disconnected
	public func centralManager(central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
		guard let _peripheral = peripheralForPeripheral(peripheral) else {
			return
		}
		if let error = error {
			_peripheral.btCentralManagerReceivedDisconnectError(error)
			return
		}
		_peripheral.onDisconnected()
	}
	
	/// CoreBluetooth is restoring state.
	public func centralManager(central: CBCentralManager, willRestoreState dict: [String : AnyObject]) {
	#if os(iOS)
		
		//TODO:
		
	#endif
	}
}
