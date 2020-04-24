//
//  ConsumerSystemsController.swift
//
//  Copyright (c) 2020 Daniel Murfin
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Cocoa
import OTPKit

/**
 Consumer Systems Controller Delegate
 
 Required methods for objects implementing this delegate.

*/

protocol ConsumerSystemsControllerDelegate: AnyObject {
    
    /**
     Notifies the delegate which system numbers should be observed.
     
     - Parameters:
        - systemNumbers: The system numbers to be observed.
     
    */
    func shouldObserveSystemNumbers(_ systemNumbers: [OTPSystemNumber])
    
}

/**
 Consumer Systems Controller
 
 Displays a list of System Numbers which should be observed by a Consumer.

*/

final class ConsumerSystemsController: NSViewController {
    
    /// The table view displaying system numbers.
    @IBOutlet var tableView: NSTableView!
    
    /// The valid range of system numbers.
    static let validSystemNumbers = [OTPSystemNumber](1...200)
    
    /// The currently observed system numbers.
    var observedSystemNumbers: [OTPSystemNumber]?
    
    /// The currently discovered system numbers.
    var discoveredSystemNumbers: [OTPSystemNumber]?
    
    /// The delegate which should receive notifications from the controller.
    weak var delegate: ConsumerSystemsControllerDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    /**
     Observes or stops observing the system number for the button clicked.
     
        - Parameters:
            - sender: The button sending this action.
     
    */
    @objc func changeObserveSystemNumber(_ sender: NSButton) {
        
        // system numbers should have been provided
        guard var observedSystemNumbers = self.observedSystemNumbers else { return }
        
        switch sender.tag {
        case 0:

            observedSystemNumbers = sender.checked ? Self.validSystemNumbers : []
            
            // update the stored system numbers being observed
            self.observedSystemNumbers = observedSystemNumbers
            
            tableView.reloadData()
            
        default:
            
            // the system number
            let systemNumber = OTPSystemNumber(sender.tag)

            if observedSystemNumbers.contains(systemNumber) {
                observedSystemNumbers.removeAll(where: { $0 == systemNumber })
            } else {
                observedSystemNumbers.append(systemNumber)
            }
            
            // update the system numbers
            self.observedSystemNumbers = observedSystemNumbers

            tableView.reloadData()
            
        }
        
        // notify the delegate
        delegate?.shouldObserveSystemNumbers(observedSystemNumbers)
        
    }
    
}

// MARK: -
// MARK: -

/**
 Consumer Systems Controller Extension
 
 Extensions to `ConsumerSystemsController` to handle table view data source and delegate.

*/

extension ConsumerSystemsController: NSTableViewDataSource, NSTableViewDelegate {
    
    /**
     The column identifiers used for this table view.
    */
    private enum ColumnIdentifiers: String {
        case systemNumber = "systemNumber"
        case online = "online"
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return Self.validSystemNumbers.count + 1
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        
        // there must be a column identifier
        guard let identifier = tableColumn?.identifier, let column = ColumnIdentifiers(rawValue: identifier.rawValue) else { return nil }
        
        switch column {
        case .systemNumber:
        
            // ensure this is a check cell view
            guard let checkCellView = tableView.makeView(withIdentifier: identifier, owner: self) as? CheckCellView else { return nil }
            
            // system numbers should have been provided
            guard let observedSystemNumbers = observedSystemNumbers else { return nil }
            
            switch row {
            case 0:
                
                checkCellView.check.title = "All"
                
                // check if all system numbers are observed
                checkCellView.check.checked = observedSystemNumbers.count == Self.validSystemNumbers.count
                
            default:
                
                checkCellView.check.title = "\(row)"

                // check if this system number is observed
                checkCellView.check.checked = observedSystemNumbers.contains(OTPSystemNumber(row))
                
            }
            
            // set the tag to be the row
            checkCellView.check.tag = row
            
            // add an action to the check
            checkCellView.check.action = #selector(changeObserveSystemNumber(_:))
            checkCellView.check.target = self

            return checkCellView
            
        case .online:
            
            // discovered system numbers should have been provided
            guard let discoveredSystemNumbers = discoveredSystemNumbers else { return nil }
            
            switch row {
            case 0:
                return nil
            default:
                
                // ensure this is an image cell view
                guard let imageCellView = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView else { return nil }
                
                imageCellView.imageView?.isHidden = !discoveredSystemNumbers.contains(OTPSystemNumber(row))
                
                imageCellView.imageView?.contentTintColor = .systemGreen
                
                return imageCellView
                
            }
            
        }
        
    }

}
