//
//  ViewController.swift
//  HelloMoodMetric
//
//  Created by André-John Mas on 2016-04-23, based on code sample
//  in the SDK document, dated 2015-03-21. Updated for current Swift
//  version
//

import Cocoa
import CoreBluetooth

class ViewController: NSViewController {

    let mmServiceUUID = CBUUID(string:"dd499b70-e4cd-4988-a923-a7aab7283f8e")
    let streamingCharacteristicUUID = CBUUID(string:"a0956420-9bd2-11e4-bd06-0800200c9a66")
    var centralManager : CBCentralManager?
    var peripheral: CBPeripheral?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        centralManager = CBCentralManager(delegate: self, queue: nil)
        print("waiting for bluetooth to become available")
        // Do any additional setup after loading the view.
    }
    
    override var representedObject: AnyObject? {
        didSet {
            // Update the view, if already loaded.
        }
    }
    
    func connect(peripheral: CBPeripheral!) {
        centralManager!.connectPeripheral(peripheral, options: nil)
        
        //peripheral.delegate = self
        
        // We need to have a reference to the peripheral because the connection
        // attempt will be canceled when the peripheral is deallocated
        self.peripheral = peripheral
    }
}

extension ViewController:  CBCentralManagerDelegate {
    
    func centralManagerDidUpdateState(central: CBCentralManager) {
        if central.state == .PoweredOn {
            print("bluetooth enabled, scanning for rings")
            // Start scanning for devices that support the Moodmetric service
            centralManager!.scanForPeripheralsWithServices([mmServiceUUID], options: nil)
        }
    }
    
    func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
    
        print("found a ring, connecting to it")
        // Stop scanning
        centralManager!.stopScan()
        // Connect to the ring
        connect(peripheral)
    }
    
    func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        print("connected, discovering services")
        peripheral.delegate = self
        peripheral.discoverServices([mmServiceUUID])
    }
}

extension ViewController: CBPeripheralDelegate {
    
    func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        // Loop discovered services to find the MM service
        // (though there should be only one)
        for service in peripheral.services! {
            if service.UUID == mmServiceUUID {
                print("discovered MM service")
                // Once we have the service we still need to discover
                // its characteristics
                peripheral.discoverCharacteristics([streamingCharacteristicUUID], forService: service)
                return
            }
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        // Loop discovered characteristics to find the streaming characteristic
        for characteristic in service.characteristics! {
            if characteristic.UUID == streamingCharacteristicUUID {
                print("discovered streaming characteristic, enabling notifications")
                // To receive measurements from the ring we
                // need to enable notifications
                peripheral.setNotifyValue(true, forCharacteristic: characteristic)
                return
            }
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        
        let dateFormatter = NSDateFormatter()
        dateFormatter.timeZone = NSTimeZone(name: "UTC")
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let dateStr = dateFormatter.stringFromDate(NSDate())
        
        let data = characteristic.value
        var payload = [UInt8](count: data!.length, repeatedValue: 0)
        data!.getBytes(&payload, length:data!.length)
        // Decode payload (status & mood metric)
        let status = Int(payload[0])
        let mm = Int(payload[1])
        // Instant EDA (Electrodermal activity) is in payload bytes 2 and 3 in big-endian format
        let instant = (Int(payload[2]) << 8) | Int(payload[3])
        let ax = Double(payload[4])/255*4 - 2
        let ay = Double(payload[5])/255*4 - 2
        let az = Double(payload[6])/255*4 - 2
        // Acceleration magnitude (g)
        let a = sqrt(ax*ax + ay*ay + az*az)
        print("\(dateStr) - ", String(format: "st:%02x mm:%d eda:%d a:%.2f", status, mm, instant, a))
    }
}
