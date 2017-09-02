//
//  ViewController.swift
//  BLE Locator
//
//  Created by Yeo Kheng Meng on 12/8/17.
//  Copyright © 2017 Yeo Kheng Meng. All rights reserved.
//

import UIKit
import CoreLocation
import Socket

class ViewController: UIViewController, BLEHandlerDelegate{
    
    let TAG: String = "ViewController"
    let NUM_LEDS: Int = 64
    
    var bleHandler: BLEHandler!
    
    let portNumber: Int = 55555
    
    var sendSocket: Socket?
    
    var brightness: Int = 0
    var maxDistance: Double = 5.0
    
    @IBOutlet weak var bleScanSwitch: UISwitch!
    
    @IBOutlet weak var brightnessStepper: UIStepper!
    @IBOutlet weak var brightnessValueLabel: UILabel!
    
    @IBOutlet weak var maxDistanceSlider: UISlider!
    @IBOutlet weak var maxDistanceValueLabel: UILabel!
    
    
    let piColourAssigment: Dictionary<String, Array<Int>> = ["B3": [1,0,0], "39": [0, 1, 0], "27": [0, 0, 1]]
    

    override func viewDidLoad() {
        super.viewDidLoad()
        
        bleScanSwitch.addTarget(self, action: #selector(bleScanSwitchValueDidChange), for: .valueChanged)
        brightnessStepper.addTarget(self, action: #selector(brightnessStepperValueDidChange), for: .valueChanged)
        
        maxDistanceSlider.addTarget(self, action: #selector(distanceSliderValueDidChange), for: .valueChanged)

        brightnessStepperValueDidChange(sender: brightnessStepper)
        distanceSliderValueDidChange(sender: maxDistanceSlider)
        
        //Start BLEHandler and ask it to pass callbacks to UI (here)
        bleHandler = BLEHandler(delegate: self)
        
        do {
            sendSocket = try Socket.create(family: Socket.ProtocolFamily.inet, type: Socket.SocketType.datagram, proto: Socket.SocketProtocol.udp)
        } catch {
            print("Error creating socket \(error)")
        }
        


        
    }
    
    func bleScanSwitchValueDidChange(sender:UISwitch) {
        
        if sender.isOn {
            bleHandler.bleScan(start: true)
        } else {
            bleHandler.bleScan(start: false)
        }

    }
    
    
    func brightnessStepperValueDidChange(sender: UIStepper){
        brightness = Int(sender.value)
        brightnessValueLabel.text = String(brightness)
    }
    
    
    func distanceSliderValueDidChange(sender: UISlider){
        maxDistance = Double(sender.value)
        maxDistanceValueLabel.text = String(format: "%.1f", maxDistance)
    }
    
    

    
    override func viewDidDisappear(_ animated: Bool) {
        sendSocket?.close()
        bleHandler.bleScan(start: false)
    }
    
    

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    //BLEHandlerDelegate
    
    func newDeviceScanned(name: String, uuid: UUID, rssi: Double, distance: Double, advertisementData: [NSObject : AnyObject]!) {
    
        
        let components: [String] = name.components(separatedBy: "-")
        
        if components.count != 3{
            return
        }

        let id: String = components[1]
        let hostAddress: String = components[2]
        
        var colourAssignment: Array<Int>? = piColourAssigment[id]
        
        if colourAssignment == nil {
            colourAssignment = [1,1,1]
        }
        
        if let rpiIP = generateIPAddress(lastOctet: hostAddress){
            sendPacket(ipAddress: rpiIP, distance: distance, maxDistance: maxDistance, red: colourAssignment![0] * brightness, green: colourAssignment![1] * brightness, blue: colourAssignment![2] * brightness)
        }
    
    }
    
    //We assumed RPi is on the same /24 subnet
    func generateIPAddress(lastOctet: String) -> String? {
        if let addr = getWiFiAddress() {
            //print("iOS Wifi IP is " + addr)
            
            let addressComponents: [String] = addr.components(separatedBy: ".")
            let myLastOctet: String = addressComponents[addressComponents.count - 1]
            
            let subnet: String = String(addr.characters.dropLast(myLastOctet.characters.count))
            
            //Combine our subnet with that of the Rpi host address
            let rPiIP: String = subnet.appending(lastOctet)

            return rPiIP
        } else {
            print("No WiFi address")
            return nil
        }
    }
    
    
    func sendPacket(ipAddress: String, distance: Double, maxDistance: Double, red: Int, green: Int, blue: Int){
        
        do{
            

            
            var ledsToTurnOn: Int = Int(((maxDistance - distance) / maxDistance) * Double(NUM_LEDS))
        
            if ledsToTurnOn > NUM_LEDS {
                ledsToTurnOn = NUM_LEDS
            }

            
            let dataStr: String = String.localizedStringWithFormat("%d %d %d %d", ledsToTurnOn, red, green, blue)
 

            if let address: Socket.Address = Socket.createAddress(for: ipAddress, on: Int32(portNumber)){
                try sendSocket?.write(from: dataStr, to: address)
            }
            
            
        } catch {
            print("Error in sending \(error)")
        }
        
    }
    //Obtained from https://stackoverflow.com/a/30754194
    func getWiFiAddress() -> String? {
        var address : String?
        
        // Get list of all interfaces on the local machine:
        var ifaddr : UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        guard let firstAddr = ifaddr else { return nil }
        
        // For each interface ...
        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee
            
            // Check for IPv4 or IPv6 interface:
            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {
                
                // Check interface name:
                let name = String(cString: interface.ifa_name)
                if  name == "en0" {
                    
                    // Convert interface address to a human readable string:
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                &hostname, socklen_t(hostname.count),
                                nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                }
            }
        }
        freeifaddrs(ifaddr)
        
        return address
    }
    

}

